(function () {
  var header = document.querySelector('.site-header');
  var el = header && header.querySelector('.name-mask');
  if (!el) return;

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  var shrinkDistance = 400; // px of scroll over which the shrink completes
  var baseMargin, startFontPx, minFontPx, fullHeight;
  var lastProgress = -1;
  var queued = false;
  var enabled = false;

  function reset() {
    el.style.fontSize = '';
    el.style.backgroundPositionY = '';
    header.style.marginBottom = '';
  }

  // Measure at full size; the header is in normal flow, so its height must be
  // compensated as it shrinks or the page height changes under the scroll position.
  function measure() {
    reset();
    baseMargin = parseFloat(getComputedStyle(header).marginBottom);
    startFontPx = parseFloat(getComputedStyle(el).fontSize);
    minFontPx = startFontPx * 0.55;
    fullHeight = header.offsetHeight;
    lastProgress = -1;
  }

  function update() {
    queued = false;
    if (!enabled) return;
    var progress = Math.min(1, Math.max(0, window.scrollY / shrinkDistance));
    if (progress === lastProgress) return; // past the shrink range, nothing changes
    lastProgress = progress;
    el.style.backgroundPositionY = (progress * 100) + '%';
    el.style.fontSize = (startFontPx - progress * (startFontPx - minFontPx)) + 'px';
    header.style.marginBottom = (baseMargin + fullHeight - header.offsetHeight) + 'px';
  }

  function schedule() {
    if (!queued) {
      queued = true;
      requestAnimationFrame(update);
    }
  }

  function onResize() {
    measure();
    schedule();
  }

  function enable() {
    enabled = true;
    measure();
    update();
    window.addEventListener('scroll', schedule, { passive: true });
    window.addEventListener('resize', onResize);
  }

  function disable() {
    enabled = false;
    window.removeEventListener('scroll', schedule);
    window.removeEventListener('resize', onResize);
    reset();
  }

  if (!reduceMotion.matches) enable();
  reduceMotion.addEventListener('change', function (e) {
    if (e.matches) disable(); else enable();
  });
})();
