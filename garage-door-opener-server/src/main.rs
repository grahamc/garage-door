use std::sync::Arc;

use actix_web::{get, post, web, App, HttpResponse, HttpServer, Responder};
use clap::Parser;
use serde::Serialize;
use tokio::process::Command;
use tokio::sync::Mutex;
use tokio::time::{sleep, Duration};

struct RateLimiter {
    tokens: usize,
    capacity: usize,
    refill_rate: usize,
}

impl RateLimiter {
    fn new(capacity: usize, refill_rate: usize) -> Self {
        Self {
            tokens: capacity,
            capacity,
            refill_rate,
        }
    }

    async fn take(&mut self) -> bool {
        if self.tokens > 0 {
            self.tokens -= 1;
            true
        } else {
            false
        }
    }

    async fn refill(&mut self) {
        self.tokens = (self.tokens + self.refill_rate).min(self.capacity);
    }
}

#[post("/door/{side}")]
async fn post_door(path: web::Path<String>, data: web::Data<AppState>) -> impl Responder {
    let side = path.into_inner();
    if side != "left" && side != "right" {
        return HttpResponse::BadRequest()
            .body("Invalid side parameter. Must be 'left' or 'right'.");
    }

    println!("locking");
    let mut rate_limiter = data.rate_limiter.lock().await;
    if !rate_limiter.take().await {
        return HttpResponse::TooManyRequests().body("Rate limit exceeded. Try again later.");
    }

    drop(rate_limiter); // Release the lock before starting the service

    println!("starting");
    let service_name = format!("garage-door@{}.service", side);
    let output = Command::new("systemctl")
        .arg("start")
        .arg(&service_name)
        .output()
        .await;

    println!("hi");
    match output {
        Ok(_) => HttpResponse::Ok().body(format!("Started {}", service_name)),
        Err(err) => {
            println!("Failed to start {}: {}", service_name, err);

            HttpResponse::InternalServerError().body("failed")
        }
    }
}

#[get("/door/{side}")]
async fn get_door(path: web::Path<String>) -> impl Responder {
    let side = path.into_inner();
    if side != "left" && side != "right" {
        return HttpResponse::BadRequest().json(StatusResponse {
            status: "Invalid side parameter. Must be 'left' or 'right'.".to_string(),
        });
    }

    if side == "right" {
        return HttpResponse::Ok().json(StatusResponse {
            status: "unknown".to_string(),
        });
    }

    let output = Command::new("gpioget")
        .arg("--chip")
        .arg("gpiochip0")
        .arg("--bias")
        .arg("pull-up")
        .arg("--active-low")
        .arg("--strict")
        .arg("--numeric")
        .arg("20") // pin 20, gpio 20 for pimeroni automation hat input #2. #1 seems dead?
        .output()
        .await;

    match output {
        Ok(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let status = match stdout.trim() {
                "0" => "open",
                "1" => "closed",
                _ => "unknown",
            };
            HttpResponse::Ok().json(StatusResponse {
                status: status.to_string(),
            })
        }
        Ok(output) => {
            println!("Command exited with non-zero status: {:?}", output);
            HttpResponse::InternalServerError().json(StatusResponse {
                status: "Failed to get door status.".to_string(),
            })
        }
        Err(err) => {
            println!("Failed to execute command: {}", err);
            HttpResponse::InternalServerError().json(StatusResponse {
                status: "Failed to get door status.".to_string(),
            })
        }
    }
}

struct AppState {
    rate_limiter: Arc<Mutex<RateLimiter>>,
}

#[derive(Serialize)]
struct StatusResponse {
    status: String,
}

#[derive(Parser, Debug)]
#[clap(
    name = "garage_door_webserver",
    version = "1.0",
    author = "Your Name",
    about = "A simple web server for garage doors"
)]
struct Opt {
    /// IP address to listen on
    #[clap(short, long, default_value = "127.0.0.1")]
    ip: String,

    /// Port to listen on
    #[clap(short, long, default_value = "8080")]
    port: u16,
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let opt = Opt::parse();

    let rate_limiter = Arc::new(Mutex::new(RateLimiter::new(10, 1)));

    // Start the refill task
    let rl_clone = rate_limiter.clone();
    tokio::spawn(async move {
        let rl = rl_clone;
        loop {
            sleep(Duration::from_secs(1)).await;
            rl.lock().await.refill().await;
        }
    });

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(AppState {
                rate_limiter: rate_limiter.clone(),
            }))
            .service(post_door)
            .service(get_door)
    })
    .bind((opt.ip.as_str(), opt.port))?
    .run()
    .await
}
