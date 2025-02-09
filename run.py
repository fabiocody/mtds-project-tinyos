#!/usr/bin/python

DBG_CHANNELS = "err data th ack"
TOPO_FILE = "linkgain.out"
#NOISE_FILE = "/usr/src/tinyos/tos/lib/tossim/noise/meyer-heavy.txt"
NOISE_FILE = "/usr/src/tinyos/tos/lib/tossim/noise/casino-lab.txt"

from TOSSIM import *
from random import *
import sys
from argparse import ArgumentParser

t = Tossim([])
r = t.radio()

parser = ArgumentParser()
parser.add_argument('--number-motes', '-n', type=int, default=10)
parser.add_argument('--time', '-t', type=int, default=300)
parser.add_argument('--seed', '-s', type=int, default=42)
args = parser.parse_args()

N_MOTES = args.number_motes
SIM_TIME = args.time
t.randomSeed(args.seed)

for channel in DBG_CHANNELS.split():
    t.addChannel(channel, sys.stdout)


#add gain links
f = open(TOPO_FILE, "r")
lines = f.readlines()
for line in lines:
    s = line.split()
    if (len(s) > 0):
        if s[0] == "gain":
            r.add(int(s[1]), int(s[2]), float(s[3]))
        elif s[0] == "noise":
            r.setNoise(int(s[1]), float(s[2]), float(s[3]))

#add noise trace
noise = open(NOISE_FILE, "r")
lines = noise.readlines()
for line in lines:
    str = line.strip()
    if (str != ""):
        val = int(float(str))
        for i in range(0, N_MOTES):
            t.getNode(i).addNoiseTraceReading(val)


for i in range (0, N_MOTES):
    time=i * t.ticksPerSecond() / 100
    m=t.getNode(i)
    m.bootAtTime(time)
    m.createNoiseModel()
    print "Booting ", i, " at ~ ", time*1000/t.ticksPerSecond(), "ms"

time = t.time()
lastTime = -1
while (time + SIM_TIME * t.ticksPerSecond() > t.time()):
    timeTemp = int(t.time()/(t.ticksPerSecond()*10))
    if( timeTemp > lastTime ): #stampa un segnale ogni 10 secondi... per leggere meglio il log
        lastTime = timeTemp
        print "---------------------------------- SIMULATION: ~", lastTime*10, " s ----------------------"
    t.runNextEvent()
print "---------------------------------- END OF SIMULATION -------------------------------------"
