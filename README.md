# Advanced Colour Passing

This repository contains the source code of the advanced colour passing
algorithm that has been presented in the paper
"Colour Passing Revisited: Lifted Model Construction with Commutative Factors"
by Malte Luttermann, Tanya Braun, Ralf Möller, and Marcel Gehrke (AAAI 2024).

Our implementation uses the [Julia programming language](https://julialang.org).

## Computing Infrastructure and Required Software Packages

All experiments were conducted using Julia version 1.8.1 together with the
following packages:
- Combinatorics v1.0.2
- Graphs v1.8.0
- Multisets v0.4.4
- StatsBase v0.34.0

Moreover, we use openjdk version 11.0.20 to run the (lifted) inference
algorithms, which are integrated via
`instances/ljt-v1.0-jar-with-dependencies.jar`.

## Instance Generation

First, the input instances must be generated.
To do so, run `julia instance_generator.jl all` in the `src/` directory.
The input instances are then written to `instances/input/intra` (these are the
instances for experiments regarding symmetries within factors) and to
`instances/input/inter` (these are the instances for experiments regarding
symmetries between factors having permuted argument lists).

## Running the Experiments

After the instances have been generated, the experiments can be started by
running `julia run_eval.jl all` in the `src/` directory.
The (lifted) inference algorithms are then directly executed by the Julia
script.
All results are written into the `results/` directory.

To create the plots, run `julia prepare_plot.jl` and `julia prepare_offline_plot`
in the `results/` directory to combine the obtained run times into averages and
afterwards execute the R scripts `plot.r` and `plot-offline.r` (also in the
`results/` directory).
The R script will then create a bunch of `.pdf` files in the `results/` directory
containing the plots of the experiments.