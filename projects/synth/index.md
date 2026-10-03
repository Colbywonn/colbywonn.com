---
layout: default
title: Poly-Synth
description: A 3-voice polyphonic synthesizer ASIC, taped out on Tiny Tapeout SKY26c.
---

# Poly-Synth

<p class="status">Taped out on Tiny Tapeout SKY26c, silicon pending</p>
<p><a href="https://github.com/Colbywonn/tt-poly-synth" target="_blank" rel="noopener">Repository on GitHub</a></p>

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

<!-- TODO: your words. Golden models per module, mutation testing to confirm the testbenches catch bugs, FPGA MIDI playback. Add the scope frequency check if you do it. -->

## Status and next steps

<!-- TODO: taped out on SKY26c, silicon expected in about a year. What you'll do at bring-up. -->
