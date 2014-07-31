if (!EPrints.XHTML) EPrints.XHTML = {};

EPrints.XHTML.Modal = Class.create({
  container: null,

  initialize: function(opts) {
    if (!opts.onClose)
      opts.onClose = function() { };
    if (!opts.onShow)
      opts.onShow = function() { };
    this.opts = opts;

    this.container = new Element('div', {
      'class': 'ep_modal'
    });
    this.container.hide();
    $(document.body).insert(this.container);

    this.container.update(opts.content);

    var height = this.container.getHeight();
    this.container.style.marginTop = -1 * height / 2 + 'px';

    this.show();
  },

  show: function() {
    this.overlay = new EPrints.XHTML.Overlay({
      onClose: function() {
        this.opts.onClose(this);

        this.overlay = undefined;
        this.hide();
      }.bind(this)
    });
    this.container.show();
    this.opts.onShow.defer();
  },

  hide: function() {
    this.container.hide();
    if (this.overlay)
      this.overlay.hide();
  },

  remove: function() {
    this.hide();
    this.container.remove();
  }
});
