if (EPrints.Workflow.Component.Field == undefined)
  EPrints.Workflow.Component.Field = {};

EPrints.Workflow.Component.Field.DataobjRef = Class.create(EPrints.Workflow.Component, {
  initialize: function($super, prefix, opts) {
    $super(prefix, opts);
    this.field = opts.field;
    this.field_values = $(this.prefix + '_content_field_values');
    Sortable.create(this.field_values, {
      onUpdate: function() {
        this.onChange(this);
      }.bind(this)
    });
    this.field_values.addClassName('ep_draggable');
  },

  action_close: function() {
    this.dialog.hide();
  },

  action_reset: function() {
    this.dialog.hide();
    this.dialog.remove();
    this.dialog = undefined;
    this.action_open_add_dialog();
  },

  action_open_add_dialog: function() {
    var params = this.parameters({
      action: 'render_add_dialog'
    });

    if (this.dialog) {
      this.results.update('');
      this.dialog.container.down('input[data-action="search"]').click();
      this.dialog.show();
      return;
    }

    new Ajax.Request(eprints_http_cgiroot + '/users/home', {
      method: 'post',
      parameters: params,
      onSuccess: function(transport) {
        this.dialog = new EPrints.XHTML.Modal({
          content: transport.responseText,
          onShow: function() {
            // hackery - simple search normally uses a 'q' field
            var input = this.dialog.container.down('input#q');
            if (input) {
              input.focus();
              new EPrints.XHTML.InputObserver(input, {
                onChange: function(event) {
                  this.action_search(event);
                }.bindAsEventListener(this)
              });
            }
          }.bind(this)
        });
        this.initialize_actions(this.dialog.container);
        this.results = $(this.prefix + '_results');
      }.bind(this)
    });
  },

  action_search: function(e) {
    // need to send the value too
    var params = this.parameters({
      action: 'render_results'
    });
    var sparams = e.findElement().up('form').serialize(true);
    for(var i in sparams) {
      params[i] = sparams[i];
    }

    this.results.addClassName('ep_loading');

    new Ajax.Request(eprints_http_cgiroot + '/users/home', {
      method: 'post',
      parameters: params,
      onSuccess: function(transport) {
        this.results.update(transport.responseText);

        this.results.removeClassName('ep_loading');

        // activate the buttons
        this.initialize_actions(this.results);

        // make the row clickable
        var li = this.results.down('li');
        while(li) {
          li.observe('click', function(e, li) {
            if (li.hasClassName('ep_selected'))
              li.down('input[data-action="remove"]').click();
            else
              li.down('input[data-action="add"]').click();
          }.bindAsEventListener(this, li));
          li = li.next('li');
        }
      }.bind(this)
    });
  },

  action_add: function(e) {
    var ele = e.findElement();

    var id = ele.getAttribute('data-id');
    var content = ele.getAttribute('data-content');

    this.addRow(id, content);
  },

  action_remove: function(e) {
    var ele = e.findElement();

    var id = ele.getAttribute('data-id');
    var row;

    // unselect from value list with no id saved
    if (id == undefined)
    {
      // find the top-level li
      for(row = ele; row.parentNode.id != this.field_values.id; row=row.parentNode)
        ;
    }
    // unselect from value list with id or from results dialog (which always
    // has an id)
    else
    {
      row = $(this.prefix + '_' + this.field + '_' + id);
    }

    this.removeRow(id, row);
  },

  /**
   * Add a value.
   */
  addValue: function(value) {
    // already got an entry for this record
    if (value.id && $(this.prefix + '_' + this.field + '_' + value.id))
      return;

    var params = this.parameters({
      action: 'render_row_content'
    });

    for(var key in value)
    {
      var _key = this.prefix + '_' + this.field + '_' + key;
      if (params[_key] == undefined) params[_key] = [];
      if (!params[_key].push) params[_key] = [params[_key]];
      params[_key].push(value[key]);
    }

    new Ajax.Request(eprints_http_cgiroot + '/users/home', {
      method: 'post',
      parameters: params,
      onSuccess: function(transport) {
        this.addRow(value.id, transport.responseText);
      }.bind(this)
    });
  },

  /**
   * Remove a value. Only supports {id: } currently.
   */
  removeValue: function(value) {
    if (!value.id) return;
    var content = $(this.prefix + '_' + this.field + '_' + value.id);
    if (content) {
      this.removeRow(value.id, content);
    }
  },

  addRow: function(id, content) {
    var ele = this.field_values.insert({
       bottom: content
    });
    this.initialize_actions(ele);
    Sortable.destroy(this.field_values);
    Sortable.create(this.field_values, {
      onUpdate: function() {
        this.onChange(this);
      }.bind(this)
    });

    var result_row = $(this.prefix + '_' + this.field + '_' + id + '_result');
    if (result_row) {
      result_row.addClassName('ep_selected');
      result_row.removeClassName('ep_unselected');
    }

    this.onChange(this);

    this.fire('ep:add', {
      id: id,
      content: content
    });
  },

  removeRow: function(id, content) {
    content.remove();

    var result_row = $(this.prefix + '_' + this.field + '_' + id + '_result');
    if (result_row) {
      result_row.addClassName('ep_unselected');
      result_row.removeClassName('ep_selected');
    }

    this.onChange(this);

    this.fire('ep:remove', {
      id: id,
      content: content
    });
  }
});
