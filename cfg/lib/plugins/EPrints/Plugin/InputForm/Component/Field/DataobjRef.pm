package EPrints::Plugin::InputForm::Component::Field::DataobjRef;

=head1 NAME

EPrints::Plugin::InputForm::Component::Field::DataobjRef

=head1 DESCRIPTION

A Javascript component that provides a dialog box to search for and pick from
existing items. If the user has permission to create items a create button
links to the workflow for a new item.

XHTML fragments rendered by this module are post-processed by the Javascript
class to turn buttons into Javascript actions. Data are passed to Javascript
via 'data-' attributes on the button(s).

The Javascript class can in turn call this component via an internal button
action (update_from_form) to e.g. render search results. This is implemented
similarly to Screen actions but doesn't perform any permissions checks.

Search uses the highest qs score Search plugin for C<[datasetid]/simple>.

=head1 SYNOPSIS

	<component type="Field::DataobjRef"><field ref="projects" /></component>
	
	<component type="Field::DataobjRef" autocommit="yes">
		<field ref="users" />
	</component>

Field must be of type C<dataobjref>.

=head1 OPTIONS

=over 4

=item autocommit = no

Set to "yes" to commit changes to the object during Ajax callbacks. Otherwise
changes will only be written when the user clicks a normal workflow action
(Next page etc.).

=back

=head1 METHODS

=over 4

=cut

use base qw( EPrints::Plugin::InputForm::Component::Field );

use strict;

sub new
{
	my ($class, %params) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{visible} = "all";
	$self->{actions} = [qw( create edit render_add_dialog render_results render_row_content render_id_from_value )];

	return $self;
}

sub parse_config
{
	my ($self, $node) = @_;

	foreach my $child ($node->childNodes)
	{
		my $name = $child->localName;
		if ($name eq 'script')
		{
			$node->removeChild($child);
			$self->{script} = $child->firstChild->nodeValue;
		}
	}

	$self->SUPER::parse_config($node);

	$self->{autocommit} =
		$node->hasAttribute('autocommit') &&
		$node->getAttribute('autocommit') eq 'yes';
}

=item $id = $component->id_from_value($value)

Return a unique XHTML id for the given value.

=cut

sub id_from_value
{
	my ($self, $value) = @_;

	my $field = $self->{config}{field};

	return join('_',
		$self->{prefix},
		'_value',
		$field->get_id_from_value($self->repository, $value),
	);
}

sub form_value
{
	my ($self) = @_;

	my $repo = $self->repository;
	my $field = $self->{config}{field};

	my $value = [];
	foreach my $f (@{$field->property("fields_cache")})
	{
		my @values = $repo->param(join('_', $self->{prefix}, $f->name));
		foreach my $i (0..$#values)
		{
			$value->[$i]{$f->property('sub_name')} = $values[$i];
		}
	}

	return $value;
}

sub update_from_form
{
	my ($self, $processor) = @_;

	local $self->{processor} = $processor;
	my $repo = $self->repository;
	my $field = $self->{config}{field};
	my $dataobj = $processor->{dataobj} || $processor->{eprint};

	$dataobj->set_value($field->name, $self->form_value);

	my $action = $self->get_internal_button;
	if (EPrints::Utils::is_set($action))
	{
		my $ok = 0;
		foreach my $_action (sort { length($b) <=> length($a) } @{$self->param('actions')})
		{
			if ($action =~ /^${_action}_(.+)/ || $action eq $_action)
			{
				$ok = 1;
				my $f = "action_$_action";
				$self->$f($1);
			}
		}
		if (!$ok)
		{
			$processor->add_message(
				'error',
				$repo->html_phrase('Plugin/Screen:unknown_action',
					screen => $repo->xml->create_text_node($self->get_id),
					action => $repo->xml->create_text_node($action),
				),
			);
		}
	}
}

sub wishes_to_export
{
	my ($self, $processor) = @_;

	return defined $processor->{notes}->{xhtml};
}
sub export_mimetype
{
	my ($self, $processor) = @_;

	binmode(STDOUT, ":utf8");
	return "text/html";
}
sub export
{
	my ($self, $processor) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;
	
	if ($processor->{notes}{xhtml})
	{
		print $xhtml->to_xhtml($processor->{notes}{xhtml});
		$xml->dispose($processor->{notes}{xhtml});
	}
}

sub search_plugin
{
	my ($self) = @_;

	my $repo = $self->repository;
	my $field = $self->{config}{field};

	# sf2 - need to use the Internal Search - Xapian doesn't support virtual datasets searches?

	my $dsid = $field->property( 'datasetid' );	#."_archive";
	my $dataset = $repo->dataset( $dsid );	#$field->property('datasetid'));

	my %p = ( dataset => $dataset );


	my $search_fields;


	# $dataset->search_config was added in 3.3.11 - if we don't have, use $self->search_config instead
	if( $dataset->can( 'search_config' ) )
	{
		if( defined (my $sf = $dataset->search_config( 'dataobjref' )->{search_fields} ) )
		{
			$search_fields = $sf;
		}
	}
	else
	{
		if( defined (my $sf = $self->dataset_search_config( $dataset, 'dataobjref' )->{search_fields} ) )
		{
			$search_fields = $sf;
		}
	}

	# need some weird special processing if the search contains a "/" (very likely if searching by Grant ID e.g. EP/H04874X/1)
	# in this case, EPrints splits the search terms by "/" and the search doesn't match anything
	# so if there's a "/", assume a Grant search, force the EX match
	# and don't search Name fields (cos they expect a HASH and we're giving them a SCALAR so EPrints will crash)
	# I know this is lame but the only way to fight some weird hard-coded EPrints behaviours
	 
	if( defined $search_fields->[0] && defined $search_fields->[0]->{match} )
	{
		my $clone_sf = EPrints::Utils::clone( $search_fields );
		my $q = $repo->param('q') || '';
		my $is_grant_search = $q =~ /\// ? 1 : 0;

		$clone_sf->[0]->{match} = 'EX' if $is_grant_search;

		my @kept_fields;
		foreach my $fieldname ( @{ $clone_sf->[0]->{meta_fields} || [] } )
		{
			my $field = $dataset->field( $fieldname ) or next;
			next if $field->is_virtual;		# avoids "attempt to search Compound field" error
			next if $is_grant_search && $field->isa( 'EPrints::MetaField::Name' ); # avoid EPrints trying to EX match a SCALAR to a name (ie. a HASH)

			push @kept_fields, $fieldname;
		}

		$clone_sf->[0]->{meta_fields} = \@kept_fields;

		$p{search_fields} = $clone_sf;
	}

	$p{search_fields} ||= $search_fields;

	my( $plugin ) = sort { $b->param('qs') <=> $a->param('qs') } $repo->get_plugins( \%p, 
		type => 'Search',
		can_search => 'simple/'.$dataset->base_id,
	);

	return $plugin;
}


# sf2 - this appeared in EPrints::DataSet in 3.3.11
# call by $self->search_plugin, above
sub dataset_search_config
{
        my( $self, $dataset, $searchid ) = @_;

        my $repo = $self->{repository};

        my $sconf;
        if( $dataset->id eq "archive" )
        {
                $sconf = $repo->config( "search", $searchid );
        }
        if( !defined $sconf )
        {
                $sconf = $repo->config( "datasets", $dataset->id, "search", $searchid );
        }
        if( defined $sconf )
        {
                # backwards compat. when _fulltext_ was a magic field
                foreach my $sfs (@{$sconf->{search_fields}})
                {
                        for(@{$sfs->{meta_fields}})
                        {
                                $_ = "documents" if $_ eq "_fulltext_";
                        }
                }
        }
        elsif( $searchid eq "simple" )
        {
                $sconf = $dataset->_simple_search_config();
        }
        elsif( $searchid eq "advanced" )
        {
                $sconf = $dataset->_advanced_search_config();
        }
        else
        {
                $sconf = {};
        }

        return $sconf;
}

sub return_to_url
{
	my ($self) = @_;

	my $repo = $self->repository;
	my $field = $self->{config}{field};

	my $url = $repo->current_url;
	$url->query_form(
		$self->{processor}->screen->hidden_bits,
	);
	$url->fragment($field->name);

	return $url;
}

sub edit_url
{
	my ($self, $dataobj) = @_;

	my $repo = $self->repository;

	my $url = $repo->current_url(
		host => 1,
		path => 'cgi',
		'users/home'
	);
	$url->query_form(
		screen => 'Workflow::Edit',
		dataset => $dataobj->{dataset}->base_id,
		dataobj => $dataobj->id,
	);

	return $url;
}

sub action_create
{
	my ($self) = @_;

	my $repo = $self->repository;
	my $user = $repo->current_user;
	my $field = $self->{config}{field};
	my $datasetid = $field->property('datasetid');
	my $dataset = $repo->dataset($datasetid);

	return if !$user->has_privilege("$datasetid/create");

	my $dataobj = $self->{dataobj};

	my $sub_dataobj = $dataset->create_dataobj({
		userid => $user->id,
	});

	$dataobj->set_value($field->name, [
		@{$dataobj->value($field->name)},
		{ id => $sub_dataobj->id },
	]);
	$dataobj->commit;

	my $url = $self->edit_url($sub_dataobj);
	$url->query_form(
		$url->query_form,
		return_to => $self->return_to_url,
	);

	$self->{processor}{redirect} = $url;
}

sub action_edit
{
	my ($self, $dataobjid) = @_;

	my $repo = $self->repository;
	my $field = $self->{config}{field};
	my $dataset = $repo->dataset($field->property('datasetid'));

	my $dataobj = $dataset->dataobj($dataobjid);

	my $url = $self->edit_url($dataobj);
	$url->query_form(
		$url->query_form,
		return_to => $self->return_to_url,
	);

	$self->{processor}{redirect} = $url;
}

sub action_render_add_dialog
{
	my ($self) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;
	
	if( $repo->get_lang->has_phrase( $self->html_phrase_id( $self->{config}{field}->get_name. ":" . "modal:blurb" ) ) )
	{
		$frag->appendChild( $self->html_phrase( $self->{config}{field}->get_name. ":" . "modal:blurb" ) );
	}

	my $search = $self->search_plugin;

	my $div = $xml->create_element('div');
	$frag->appendChild($div);

	my $form = $xhtml->form;
	$div->appendChild($form);

	$form->appendChild($search->render_simple_fields);

	$form->appendChild($xhtml->action_javascript(
		search => $repo->phrase('lib/submissionform:action_search'),
	));

	$frag->appendChild($xml->create_element('div',
		id => "$self->{prefix}_results",
		class => 'ep_modal_results',
	));

	$self->{processor}{notes}{xhtml} = $xhtml->modal_content(
		title => $self->html_phrase('action:add:title'),
		content => $frag,
		actions => {
			reset => $self->{repository}->phrase('lib/searchexpression:action_reset'),
			close => $self->{repository}->phrase('lib/submissionform:action_close'),
			_order => [qw( reset close )],
		},
	);
}

sub action_render_results
{
	my ($self) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;
	my $field = $self->{config}{field};

	my $frag = $xml->create_document_fragment;

	my $search = $self->search_plugin;

	$search->from_form;

	my $results = $search->execute;

	if ($results->count == 0)
	{
		$self->{processor}{notes}{xhtml} = $self->html_phrase('no_results');
		return;
	}

	my $value = $field->get_value($self->{dataobj});
	my %selected = map { $_->{id} => 1 } @$value;

	$frag->appendChild(my $ol = $xml->create_element('ol',
		class => 'ep_dataobj_list',
	));
	$results->map(sub {
		(undef, undef, my $dataobj) = @_;

		my $value = {
				id => $dataobj->id,
			};

		$ol->appendChild(my $li = $xml->create_element('li',
			id => join('_', $self->{prefix}, $field->name, $dataobj->id, "result"),
			class => $selected{$dataobj->id} ? 'ep_selected' : 'ep_unselected',
		));

		my $content = $xhtml->to_xhtml($self->render_single_value($value));

		$li->appendChild(my $ul = $xml->create_element('ul',
			class => 'ep_action_list',
		));

		# -content: XHTML to insert into component
		# -id: id of the dataobj
		$ul->appendChild($xml->create_data_element('li', $xhtml->action_javascript(
			add => $repo->phrase('lib/submissionform:action_select'),
			'data-id' => $dataobj->id,
			'data-content' => $content,
		), class => 'ep_selected_hide'));

		$ul->appendChild($xml->create_data_element('li', $xhtml->action_javascript(
			remove => $repo->phrase('lib/submissionform:action_deselect'),
			'data-id' => $dataobj->id,
			class => 'ep_unselected_hide'
		)));

		$li->appendChild($dataobj->render_citation);
	});

	$self->{processor}{notes}{xhtml} = $frag;
}

sub action_render_row_content
{
	my ($self) = @_;

	my $repo = $self->repository;

	# added value must be the last in the list
	my $value = $self->form_value->[-1];

	$self->{processor}{notes}{xhtml} = $self->render_single_value($value);
}

sub action_render_id_from_value
{
	my ($self) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;

	my $value = $self->form_value->[0];

	$self->{processor}{notes}{xhtml} = $xml->create_text_node($self->id_from_value($value));
}

sub render_content
{
	my ($self) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;
	my $user = $repo->current_user;

	my $frag = $xml->create_document_fragment;

	my $field = $self->{config}{field};
	my $datasetid = $field->property('datasetid');

	$frag->appendChild(my $field_values = $xml->create_element('ol',
		id => "$self->{prefix}_content_field_values",
		class => 'ep_dataobj_list',
	));

	foreach my $v ( @{ $self->{dataobj}->value($field->name) || [] } )
	{
		$field_values->appendChild($self->render_single_value($v));
	}

	$frag->appendChild(my $block = $xml->create_element('div', class => 'ep_block'));

	$block->appendChild($xhtml->action_javascript(
		open_add_dialog => $self->phrase('action:add:title'),
	));

	if ($user->has_privilege("$datasetid/create"))
	{
		my $action = "_internal_$self->{prefix}_create";
		$block->appendChild($xhtml->input_field(
			$action => $repo->phrase('lib/submissionform:action_create'),
			type => 'submit',
			class => 'ep_form_internal_button',
		));
	}

	my $prefix = $self->{prefix};
	my $fieldname = $field->name;

	# sf2 - this should be called from Metafield::render_input but we don't call that
        $frag->appendChild( $repo->make_javascript( <<EOJ ) );
new Metafield ('$prefix', '$fieldname' );
EOJ

	$frag->appendChild($self->render_script(
		autocommit => $self->{autocommit},
		field => $field->name,
	));

	return $frag;
}

sub render_single_value
{
	my ($self, $value) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;
	my $user = $repo->current_user;

	my $frag = $xml->create_document_fragment;

	my $field = $self->{config}{field};
	my $dataset = $repo->dataset($field->property('datasetid'));
	my $dataobj = $dataset->dataobj($value->{id});

	my $id = $self->id_from_value($value);

	$frag->appendChild(my $li = $xml->create_element('li'));
	if ($value->{id})
	{
		$li->setAttribute(id => join('_', $self->{prefix}, $field->name, $value->{id}));
	}

	foreach my $f (@{$field->property("fields_cache")})
	{
		my $name = join '_',
			$self->{prefix},
			$f->name,
		;
		$li->appendChild($xhtml->hidden_field(
			$name => $value->{$f->property('sub_name')},
		));
	}

	$li->appendChild(my $ul = $xml->create_element('ul',
		class => 'ep_action_list',
	));

	if (defined $dataobj && $user->allow($dataset->base_id . '/edit', $dataobj))
	{
		my $action = "_internal_$self->{prefix}_edit_".$dataobj->id;
		$ul->appendChild($xml->create_data_element('li', $xhtml->input_field(
			$action => $repo->phrase('lib/submissionform:action_edit'),
			type => 'submit',
			class => 'ep_form_internal_button',
		)));
	}

	$ul->appendChild($xml->create_data_element('li', $xhtml->action_javascript(
		remove => $repo->phrase('lib/submissionform:action_deselect'),
		'data-id' => $value->{id},
	)));

	$li->appendChild($field->render_value($repo, [$value]));

	return $frag;
}

sub render_script
{
	my ($self, %opts) = @_;

	my $type = $self->get_subtype;
	$type =~ s/::/\./g;

	my $opts = JSON->new->utf8->encode(\%opts);

	my $callback = "";
	if ($self->{script})
	{
		$callback = "(function() { $self->{script} }).bind(component)();";
	}

	return $self->repository->make_javascript(<<"EOJ");
var component = new EPrints.Workflow.$type('$self->{prefix}', $opts);
$callback
EOJ
}

1;
