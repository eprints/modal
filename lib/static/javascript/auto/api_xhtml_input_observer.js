if (!EPrints.XHTML) EPrints.XHTML = {};

/**
 * Watch for changes on a text input
 *
 */
EPrints.XHTML.InputObserver = Class.create({
  initialize: function(element, options) {
    element = $(element);
    this.element = element;
    this.options = options || {};

    this.value = element.value;

    this.options.frequency = this.options.frequency || .4;
    this.options.minChars = this.options.minChars || 1;
    this.options.onChange = this.options.onChange || function() {};

    this.onKeyPressObserver = this.onKeyPress.bindAsEventListener(this);
    this.element.observe('keyup', this.onKeyPressObserver);
  },

  hasChanged: function() {
    // has it changed?
    if (this.element.value == this.value) return false;
    this.value = this.element.value;

    return true;
  },

  onKeyPress: function(event) {
    if (this.observer) clearTimeout(this.observer);

    if (!this.hasChanged()) return;

    this.observer = setTimeout(this.onObserverEvent.bind(this, event), this.options.frequency*1000);
  },

  onObserverEvent: function(event) {
    // sufficient length?
    if (this.element.value.length < this.options.minChars) return;

    this.options.onChange(event, this);
  },

  remove: function() {
    this.element.stopObserving('keyup', this.onKeyPressObserver);
  }
});
