#/bin/sh

set -eux

if [ "${1:-}" == "outer" ]; then
  gpio=13
else
  gpio=19
fi

gpioset --mode=time --sec=1 pinctrl-bcm2835 "$gpio"=1
