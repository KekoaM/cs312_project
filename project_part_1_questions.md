---
title: Course Project Part 1 Questions
author: |
  | Kai Morita-McVey
  | moritamk@oregonstate.edu
date: \today
geometry: "left=1cm,right=1cm,top=2cm,bottom=2cm"
---

## What provides automatic dnf updates

I usually use [Cockpit](https://cockpit-project.org/) for my server administration and it has an optional addon for package management that does automatic updates. As I was not using this, I had to look up what package provides this with the answer being `dnf-automatic`.

## What is the most commonly used container image for minecraft

Answer is `docker.io/itzg/minecraft-server`

## How to use Modrith modpacks with docker-minecraft-server

Set the corresponding environment variables when running the image. See [https://docker-minecraft-server.readthedocs.io/en/latest/mods-and-plugins/](https://docker-minecraft-server.readthedocs.io/en/latest/mods-and-plugins/) for more info
