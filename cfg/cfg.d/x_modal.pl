# modal.pl

# Bazaar Configuration

$c->{plugins}{"InputForm::Component::Modal"}{params}{disable} = 0;
$c->{plugins}{"InputForm::Component::Modal::ItemSearch"}{params}{disable} = 0;

$c->{plugins}{"InputForm::Component::Field::DataobjLookup"}{params}{disable} = 0;
$c->{plugins}{"InputForm::Component::Field::MyDataobj"}{params}{disable} = 0;

$c->{plugins}{"InputForm::Component::Field::DataobjRef"}{params}{disable} = 0;

=item $frag = $xhtml->modal_content( PARAMS )

Render the content to pass to a Javascript modal dialog.

=over 4

=item title

=item content

=back

=cut

sub EPrints::XHTML::modal_content
{
	my ($self, %params) = @_;

	my $xml = $self->{repository}->xml;

	$params{class} = join(' ', 'ep_sr_component', ($params{class} || ''));

	my $div = $xml->create_element('div',
		class => $params{class},
	);

	$div->appendChild($xml->create_data_element('div',
		[
			[ 'div', $params{title}, class => 'ep_sr_title', ],
		],
		class => 'ep_sr_title_bar ep_modal_title',
	));
	$div->appendChild($xml->create_data_element('div',
		$params{content},
		class => 'ep_sr_content ep_modal_content'
	));
	$div->appendChild(my $action_bar = $xml->create_element('div', class => 'ep_modal_action_bar'));

	my $actions = $params{actions} || {};
	my $order = $actions->{_order} ||= [sort grep { $_ !~ /^_/ } keys %$actions];
	foreach my $action (@$order)
	{
		$action_bar->appendChild($self->action_javascript(
			$action => $actions->{$action},
		));
	}

	return $div;
}

=item $node = $xhtml->action_javascript( $name, $value, %opts )

Render a button suitable for calling a Javascript callback.

	$frag->appendChild($xhtml->action_javascript(
		foo => 'Foo',
	);
	
	...
	
	action_foo: function(e) {
		// e is an event object
	}

=cut

sub EPrints::XHTML::action_javascript
{
	my ($self, $action, $value, %opts) = @_;

	$opts{class} = join(' ', 'ep_form_internal_button', 'ep_component_action', ($opts{class} || ''));

	return $self->input_field(
		'' => $value,
		type => 'submit',
		'data-action' => $action,
		%opts,
	);
}

