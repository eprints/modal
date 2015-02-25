/*
 *
 * new EPrints.XHTML.Overlay({
 *  onClose: function() {
 *    // close the dialog
 *  },
 *  onFinish: function() {
 *    // overlay has finished appearing
 *  }
 * });
 *
 */

EPrints.XHTML.Overlay = Class.create({
  initialize: function(opts) {
    if (!opts)
      opts = {};

    if (!opts.onClose)
      opts.onClose = function() {};

    if (!opts.duration)
      opts.duration = .3;

    // don't let effects crunch over each other
    opts.queue = 'end';

    this.opts = opts;
    this.overlay = EPrints.XHTML.Overlay.overlay;
    this.body = $(document.body);

    this.show();
  },

  show: function() {
    if (this.effect) {
      this.effect.cancel();
    }

    // watch for clicks on the overlay (=close dialog)
    this.clickObserver =
      (function() {
        this.hide();
        this.opts.onClose();
      }).bind(this);
    this.overlay.observe('click', this.clickObserver);

    // trap ESC as if the user clicked the overlay
    this.keypressObserver =
      (function(e) {
        switch(e.keyCode) {
          /*case Event.KEY_RETURN:
            console.log('return');
            e.stop();
            return true;*/
          case Event.KEY_ESC:
            this.overlay.click();
            e.stop();
            return true;
        }
        return false;
      }).bind(this);
    Event.observe(document, 'keyup', this.keypressObserver);

    // stop the viewport scrolling
    var cwidth = document.viewport.getWidth();
    this.body.addClassName('ep_overlay');
    // stop the view jumping due to the loss of scrollbar
    if (cwidth != document.viewport.getWidth()) {
      this.bodyMarginRight = this.body.style.marginRight;
      this.body.style.marginRight = document.viewport.getWidth() - cwidth + 'px';
    }

    // re-dimension the overlay to the viewport size
    this.overlay.hide();
    var dimensions = document.viewport.getDimensions();
    this.overlay.style.width = dimensions.width + 'px';
    this.overlay.style.height = dimensions.height + 'px';

    // fade-in the overlay
    this.opts.from = 0;
    this.opts.to = .5;
    this.effect = new Effect.Appear(this.overlay, this.opts);
  },

  hide: function() {
    if (this.effect) {
      this.effect.cancel();
    }

    this.overlay.stopObserving('click', this.clickObserver);
    Event.stopObserving(document, 'keypress', this.keypressObserver);

    this.body.removeClassName('ep_overlay');
    this.body.style.marginRight = this.bodyMarginRight;

    // fade-out the overlay
    this.opts.from = .5;
    this.opts.to= 0;
    this.effect = new Effect.Fade(this.overlay, this.opts);
  }
});

Event.observe(window, 'load', function() {
  var overlay = new Element('div', {
    'class': 'ep_overlay'
  });
  EPrints.XHTML.Overlay.overlay = overlay;

  overlay.hide();
  $(document.body).insert(overlay);
});
