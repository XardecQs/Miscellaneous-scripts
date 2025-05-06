#!/bin/bash
if waydroid status | grep -q "RUNNING"; then
  #running
  waydroid session stop
fi
waydroid session start
waydroid -w container start
