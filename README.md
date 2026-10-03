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

## Running locally

GitHub Pages builds the site on every push to `main`. To preview locally, install Ruby and Jekyll, then run:

```
gem install jekyll jekyll-seo-tag jekyll-sitemap
jekyll serve
```

and open http://localhost:4000.

## Projects

- [Poly-Synth](https://github.com/Colbywonn/tt-poly-synth): a 3-voice polyphonic synthesizer ASIC, taped out on Tiny Tapeout SKY26c
