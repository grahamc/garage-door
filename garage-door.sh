#/bin/sh

set -eux

if [ "${1:-}" == "outer" ] || [ "${1:-}" == "right" ]; then
  gpio=13
else
  gpio=19
fi

gpioset --toggle 250ms,0 --chip gpiochip0 --strict "$gpio"=1
