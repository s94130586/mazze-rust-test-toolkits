#!/bin/bash

parallel-ssh -O "StrictHostKeyChecking no" -h ips -p 400 "killall -9 mazze || echo already killed"