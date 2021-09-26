#!/bin/sh

if grep "outer"; then
  echo "running outer door"
  systemctl start garage-door@outer.service
else
  echo "running inner door"
  systemctl start garage-door@inner.service
fi

