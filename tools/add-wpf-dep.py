#!/usr/bin/env python3
import json
import argparse

parser = argparse.ArgumentParser(description="Script to inject WPF dependency into a runtimeconfig.json's runtimeOptions")
parser.add_argument("in_file")
parser.add_argument("out_file")
args = parser.parse_args()

with open(args.in_file, "r") as file:
    config = json.load(file)

runtime_options = config["runtimeOptions"]
if "framework" in runtime_options:
    runtime_options["frameworks"] = [runtime_options["framework"]]
    del runtime_options["framework"]

for framework in runtime_options["frameworks"]:
    if framework["name"] == "Microsoft.WindowsDesktop.App":
        break
else:
    runtime_options["frameworks"].append({
        "name": "Microsoft.WindowsDesktop.App",
        "version": "8.0.0"
    })

with open(args.out_file, "w") as file:
    json.dump(config, file, indent=2)
