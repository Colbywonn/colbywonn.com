(function () {
  var dropdowns = document.querySelectorAll('.dropdown.disclosure');

  Array.prototype.forEach.call(dropdowns, function (dd) {
    var button = dd.querySelector('.dropdown-toggle');

    function setOpen(open) {
      dd.classList.toggle('open', open);
      button.setAttribute('aria-expanded', open ? 'true' : 'false');
    }

    button.addEventListener('click', function () {
      setOpen(!dd.classList.contains('open'));
    });

    dd.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && dd.classList.contains('open')) {
        setOpen(false);
        button.focus();
      }
    });

    dd.addEventListener('focusout', function (e) {
      if (!dd.contains(e.relatedTarget)) setOpen(false);
    });

    document.addEventListener('click', function (e) {
      if (!dd.contains(e.target)) setOpen(false);
    });
  });
})();
