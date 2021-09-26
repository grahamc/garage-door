#/bin/sh

set -eux

if [ "${1:-}" == "outer" ]; then
  gpio=13
else
  gpio=19
fi

device=$((458 + "$gpio"))
gpiodir="/sys/class/gpio/gpio${device}"

if [ ! -d "$gpiodir" ]; then
    echo "$device" > /sys/class/gpio/export
fi

while [ ! -d "$gpiodir" ]; do
    sleep 0
done

cd "$gpiodir"

echo out > direction

echo 0 > value
sleep 0.5
echo 1 > value
sleep 0.5
echo 0 > value

