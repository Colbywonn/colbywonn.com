# colbywonn.com

Source for [colbywonn.com](https://colbywonn.com), my personal site. I'm a Computer Engineering student at the University of Utah, working in digital design and verification.

The site is built with Jekyll and hosted on GitHub Pages. It uses no theme, just one layout, one stylesheet, and a couple of small scripts.

My personal experience with Jekyll is minimal, so this website was generated with AI tools such as Claude Opus 5.5.

## Layout

| Path | Contents |
| --- | --- |
| `index.md` | Home page: intro, about, and featured projects |
| `projects/` | Project index and one page per project |
| `_layouts/default.html` | The single page layout: header, nav, footer |
| `assets/css/site.css` | All styles |
| `assets/js/` | Dropdown menus and the scrolling name header |
| `assets/fonts/` | Self-hosted Quantico, Poppins, and EB Garamond |
| `assets/img/`, `assets/audio/` | Images, diagrams, and demo recordings |
| `404.html` | Not-found page |
| `_config.yml` | Site settings and plugins (`jekyll-seo-tag`, `jekyll-sitemap`) |

## Projects

- [Poly-Synth](https://github.com/Colbywonn/tt-poly-synth): a 3-voice polyphonic synthesizer ASIC, taped out on Tiny Tapeout SKY26c

## License

Except where noted below, the content and code of this website are licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/). You may copy, adapt, and share them for any purpose, including commercially, as long as you give credit (for example, "Colby Miller, colbywonn.com") and indicate if you made changes. The full license text is in [LICENSE](LICENSE).

These parts are **not** covered by CC BY 4.0:

- `headshot.jpg` and `assets/resume.pdf`: personal; all rights reserved.
- `assets/img/404-shrug.webp`: a character from *Dark Souls*, © Bandai Namco Entertainment / FromSoftware.
- `assets/audio/`: arrangements of themes from *The Legend of Zelda* (Nintendo) and *Castlevania* (Konami). The compositions belong to their rights holders.
- `assets/fonts/`: Quantico, Poppins, and EB Garamond, each under the [SIL Open Font License 1.1](https://openfontlicense.org/).
- `assets/img/open-in-new.svg`: the "open_in_new" icon from Google's [Material Symbols](https://github.com/google/material-design-icons), under the Apache License 2.0.

Each project's own repository has its own license; [tt-poly-synth](https://github.com/Colbywonn/tt-poly-synth), for example, is under the Apache License 2.0.
