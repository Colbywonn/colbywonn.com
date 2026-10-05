---
layout: default
title: Poly-Synth
description: A 3-voice polyphonic synthesizer ASIC, taped out on Tiny Tapeout SKY26c.
---

# Poly-Synth

<p class="status">Taped out on Tiny Tapeout SKY26c, silicon pending</p>
<ul class="links">
  <li><a href="https://github.com/Colbywonn/tt-poly-synth" target="_blank" rel="noopener">Repository on GitHub</a></li>
  <li><a href="https://tinytapeout.com/chips/ttsky26c/tt_um_colbywonn_poly_synth/" target="_blank" rel="noopener">Tiny Tapeout project page</a></li>
</ul>

Poly-Synth is a 3-voice polyphonic synthesizer ASIC, taped out on Tiny Tapeout SKY26c. It takes an input as a tuning word over SPI, passes it through one of 3 DDS cores, which consist of a phase accumulator and a shaper. Finally, the 3 voices are mixed arithmetically and are output via oversampling with a 1st-order Sigma-Delta module.

## Hear it

These two clips were recorded from the FPGA prototype of Poly-Synth. A Python program decodes MIDI songs into the tuning words each note needs, then bit-bangs them to a microcontroller that drives the synth.

### "Overworld" from *The Legend of Zelda*

An arrangement of the theme composed by Koji Kondo.

<audio controls preload="none" src="/assets/audio/overworld.mp3"></audio>

### "Vampire Killer" from *Castlevania*

An arrangement of the theme composed by Kinuyo Yamashita and Satoe Terashima for the original game.

<audio controls preload="none" src="/assets/audio/vampire-killer.mp3"></audio>

## System

<img src="/assets/img/block-diagram.svg" alt="Poly-Synth block diagram" width="820" height="600" loading="lazy" decoding="async">

<img src="/assets/img/die-render.webp" alt="Poly-Synth die render" width="1610" height="2258" loading="lazy" decoding="async">

## Verification

Each module was built against a golden-model testbench, and I mutation tested those testbenches to make sure they actually catch bugs. The top-level testbench runs against both the RTL and the post-layout gate-level netlist. Finally, the design ran on an iCEBreaker FPGA, playing MIDI songs straight into a pair of headphones with no amplifier.

## Status and next steps

Poly-Synth is taped out on Tiny Tapeout SKY26c, and silicon is pending. Once the chips arrive, I'll bring the design up on the Tiny Tapeout demo board, driving it over SPI from the board's RP2350 and listening through the RC filter described in the [datasheet](https://github.com/Colbywonn/tt-poly-synth/blob/main/docs/info.md).

The design has no envelope (ADSR) or other audio shaping yet, so every note starts and stops abruptly. Adding that is the plan for v2.0.
