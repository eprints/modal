if (!EPrints.Workflow)
  EPrints.Workflow = {};

if (!EPrints.Workflow.Component)
  EPrints.Workflow.Component = {};

EPrints.Workflow.Component = Class.create({
  prefix: null,

  /**
   * Create a new Component object.
   * @constructor
   * @param {string} prefix - id of the XHTML element to bind to
   * @param {hash} opts - options
   */
  initialize: function(prefix, opts) {
    if (!opts) opts = {};
    this.onChange = function() {
      if (opts.autocommit) this.commit();
      if (opts.onChange) opts.onChange(this);
    }.bind(this);

    this.prefix = prefix;
    this.container = $(prefix);

    this.initialize_actions(this.container);
  },

  initialize_actions: function(root) {
    root.select('.ep_component_action').each((function(ele) {
      ele.observe('click', function(e) {

        e.stop();

        var action = ele.getAttribute('data-action');

        this['action_' + action](e);

      }.bind(this));
    }).bind(this));
  },

  /**
   * Observe events on the component container, which can be useful for
   * trapping custom events.
   * @param {string} event
   * @param {function} listener
   */
  observe: function(event, listener) {
    this.container.observe(event, listener);
  },

  stopObserving: function(event, listener) {
    this.container.stopObserving(event, listener);
  },

  fire: function(event, memo, bubble) {
    if (bubble == undefined)
      bubble = true;
    this.container.fire(event, memo, bubble);
  },

  /**
   * Get the form parameters to post an action to this component.
   */
  parameters: function(opts) {
    if (!opts) opts = {};

    var form = this.container.up('form');
    var params = form.serialize({
        hash: true,
        submit: false
      });
    params.component = this.container.id;

    // serialize() picks up buttons
    for(var key in params)
      if (key.match(/^_internal_/))
        delete params[key];

    if (opts.action) {
      params['_internal_'+this.prefix+'_'+opts.action] = 1;
      opts.action = undefined;
    }

    return params;
  },

  /**
   * Write any changes to the database 
   */
  commit: function(opts) {
    if (!opts) opts = {};
    var params = this.parameters();

    this.fire('ep:before_commit', {
      parameters: params
    });

    new Ajax.Request(eprints_http_cgiroot + '/users/home', {
      method: 'post',
      onSuccess: function(transport) {
        if (opts.onSuccess) opts.onSuccess(transport);
        this.fire('ep:after_commit', {
          parameters: params,
          transport: transport
        });
      }.bind(this),
      parameters: params
    });
  }
});
