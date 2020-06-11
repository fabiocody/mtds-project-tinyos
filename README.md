# mtds-project-tinyos

TinyOS project for the course Middleware Technologies for Distributed Systems.

[Google Slides Presentation](https://docs.google.com/presentation/d/1KVcJqCcBrXF9TBU3N06HP5tawZ7fzjF7P6f2bDFZ1UI/edit?usp=sharing)

## Building and running

The building phase is handled with `make`. In order to build for simulation, you just need to run

```bash
$ make micaz sim
```

Then, you need to create the topology file.

```bash
$ java net.tinyos.sim.LinkLayerModel topoConfig.txt
```

Finally, you can run the simulation script with

```bash
$ ./run.py
```
