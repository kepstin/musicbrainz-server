package MusicBrainz::Server::Wizard;
use Moose;
use Carp qw( croak );

has '_current' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

has '_processed_page' => (
    is => 'rw',
    isa => 'MusicBrainz::Server::Form::Step',
    predicate => '_has_processed_page',
    clearer => '_clear_processed_page',
);

has '_session_id' => (
    is => 'rw',
    isa => 'Str',
);

has 'c' => (
    is => 'rw',
    isa => 'Object'
);

has 'loading' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has 'submitted' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has 'cancelled' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has 'page_number' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $max = scalar @{ $self->pages } - 1;
        my %ret;
        for (0..$max)
        {
            $ret{$self->pages->[$_]->{name}} = $_;
        }

        return \%ret;
    },
);

has 'pages' => (
    isa => 'ArrayRef',
    is => 'ro',
    required => 1,
    lazy => 1,
    builder => '_build_pages'
);

has $_ => (
    isa => 'CodeRef',
    traits => [ 'Code' ],
    default => sub { sub {} },
    handles => {
        $_ => 'execute',
    }
) for qw( on_cancel on_submit );

sub skip { return 0; }

sub valid {
    my ($self, $page) = @_;

    return $page->validated;
}

# The steps a request goes through to render a single page in the wizard:
#
#     [ sub process ]
#
#  1. Process submit data from the previous page
#  2. Save submitted data in session
#  3. Route to the next page (process conditionals)
#
#     [ sub render ]
#
#  4. Load previously saved data for this page from session
#  5. Load form and associated template
#  6. Add tab buttons for each step to the stash

sub _create_new_wizard {
    my ($self, $c) = @_;
    return !$c->form_posted || !$c->req->params->{wizard_session_id};
}

sub process
{
    my ($self) = @_;
    my $page;

    if ($self->_create_new_wizard($self->c)) {
        $self->_new_session;
        $self->load($self->init_object);
        $self->seed($self->c->req->params)
            if $self->c->form_posted;

        $page = $self->navigate_to_page;
    }
    elsif ($self->c->form_posted) {
        $self->_retrieve_wizard_settings;
        $page = $self->_store_page_in_session;
        $page = $self->_route ($page);
        $self->_store_wizard_settings;
    }
    else
    {
        # Shouldn't come here.
        croak "Error processing wizard.";
    }

    $self->render ($page) if $page;
}

sub initialize
{
    my ($self, $init_object) = @_;

    # if init_object is set, load it in _all_ the forms to deflate all fields
    # from the init_object in one go.  For each form store the ->value (deflated)
    # data in the session.
    if ($init_object)
    {
        my $max = scalar @{ $self->pages } - 1;
        for (0..$max)
        {
            $self->_load_page ($_, $init_object);
        }
    }
}


sub navigate_to_page
{
    my $self = shift;

    my $prepare = $self->pages->[$self->_current]->{prepare};
    &$prepare if defined $prepare;

    # If we're rendering the same page we processed, re-use the existing form.
    # (otherwise validation errors may get lost).
    return $self->_has_processed_page ? $self->_processed_page :
        $self->_load_page ($self->_current);
}

sub render
{
    my ($self, $page) = @_;

    my @steps = map {
        { title => $_->{title}, name => 'step_'.$_->{name} }
    } @{ $self->pages };
    $steps[$self->_current]->{current} = 1;

    $self->c->stash->{template} = $self->pages->[$self->_current]->{template};
    $self->c->stash->{form} = $page;
    $self->c->stash->{wizard} = $self;
    $self->c->stash->{steps} = \@steps;

    # hide errors if this is the first time (in this wizard session) that this
    # page is shown to the user.
    if (! $self->shown->[$self->_current])
    {
        $page->clear_errors;
    }

    # mark the current page as having been shown to the user.
    $self->shown->[$self->_current] = 1;
}

sub shown
{
    my $self = shift;

    $self->_store->{shown} = [] unless $self->_store->{shown};

    return $self->_store->{shown};
}

# returns the name of the current page.
sub current_page
{
    my $self = shift;

    return $self->pages->[$self->_current]->{name};
}

sub load_page
{
    my ($self, $step, $init_object) = @_;

    my $page = $self->page_number->{$step};
    $page = $step unless defined $page;

    return $self->_load_page ($page, $init_object);
}

sub _load_page
{
    my ($self, $page, $init_object) = @_;

    if ($init_object)
    {
        my $form = $self->_load_form ($page, init_object => $init_object);

        $form->field('wizard_session_id')->value ($self->_session_id);
        $self->_store->{"step ".$page} = $form->serialize;
    }

    my $serialized = $self->_store->{"step ".$page} || {};

    return $self->_load_form ($page, serialized => $serialized);
}

sub value
{
    my ($self) = @_;

    my %ret;
    my $max = scalar @{ $self->pages } - 1;
    for (0..$max)
    {
        my $value = $self->_load_page ($_)->value;

        @ret{keys %$value} = values %$value;
    }

    return \%ret;
}

sub _store_page_in_session
{
    my ($self) = @_;

    my $page = $self->_post_to_page( $self->_current, $self->c->request->params );

    # Save the processed page, if we're not navigating away from it we do not
    # want to reload it.
    $self->_processed_page ($page);

    return $page;
}

=method _transform_parameters

Allows wizards to provide their own transformation of parameters before they
are passed into the form. This may allow the wizard to take multiple representations
of POST data, for example (as in the case of the release editor).

=cut

sub _seed_parameters {
    my ($self, $params) = @_;
    return $params;
}

sub seed {
    my ($self, $params) = @_;
    $params = $self->_seed_parameters($params);

    my $max = scalar @{ $self->pages } - 1;
    for (0..$max) {
        $self->_post_to_page($_, $params);
    }
}

sub _post_to_page
{
    my ($self, $page_id, $params) = @_;

    # Hard coding this, not too intelligent?
    # It's here so we can call _post_to_page from other stuff and it doesn't
    # have to specify the wizard id...
    $params->{wizard_session_id} ||= $self->_session_id;

    my $page = $self->_load_form ($page_id);

    $page->unserialize ( $self->_store->{"step $page_id"},
                         $params );

    $self->_store->{"step $page_id"} = $page->serialize;

    return $page;
}

sub _route
{
    my ($self, $page) = @_;

    my $p = $self->c->request->parameters;
    if (defined $p->{next})
    {
        $self->find_next_page if $self->valid ($page);
        return $self->navigate_to_page;
    }
    elsif (defined $p->{previous})
    {
        $self->find_previous_page;
        return $self->navigate_to_page;
    }
    elsif (defined $p->{cancel})
    {
        $self->on_cancel($self);
        return;
    }
    elsif (defined $p->{save})
    {
        $self->submitted(1);
        return;
    }

    my $max = scalar @{ $self->pages } - 1;
    my $pos;

    for (0..$max)
    {
        $pos = $_;
        last if defined $p->{'step_'.$self->pages->[$_]->{name}};
    }

    # we are already at the requested position.
    return $self->navigate_to_page if $pos == $self->_current;

    if ($pos < $self->_current)
    {
        # just set the page when moving backward.
        $self->_current ($pos);
        return $self->navigate_to_page;
    }

    my $ret;

    # validate each page when moving forward, if a page is not valid, stop there.
    while ($pos > $self->_current)
    {
        last unless $self->find_next_page;
        $ret = $self->navigate_to_page;
        last unless $self->valid ($ret);
    }

    if ($pos != $self->_current)
    {
        # The user did not end up on the page s/he requested, perhaps s/he should be
        # informed of this -- otherwise it may be a bit confusing.

        # FIXME: add notification
    }

    return $ret;
}

sub find_next_page
{
    my ($self) = @_;

    my $page = $self->_current;

    my $max = scalar @{ $self->pages } - 1;

    while ($page < $max)
    {
        $page += 1;

        if (!$self->skip ($page))
        {
            $self->_current ($page);
            return 1;
        }
    }

    # FIXME: should probably notify someone that their form is broken.
    return 0;
}

sub find_previous_page
{
    my ($self) = @_;

    my $page = $self->_current;

    while ($page > 0)
    {
        $page -= 1;

        if (!$self->skip ($page))
        {
            $self->_current ($page);
            return 1;
        }
    }

    # FIXME: should probably notify someone that their form is broken.
    return 0;
}

around '_current' => sub {
    my ($orig, $self, $value) = @_;

    return $self->$orig () unless $value;

    # navigating away from the page just processed, so clear it.
    $self->_clear_processed_page if $self->$orig () ne $value;

    my $max = scalar @{ $self->pages } - 1;

    $value = 0 if $value < 0;
    $value = $max if $value > $max;

    return $self->$orig ($value);
};

sub _set_current
{
    my ($self, $value, $old_page) = @_;

    if (my $hook = $self->pages->[$old_page]{change_page}) {
        $hook->($self->c, $self, $value);
    }

    $self->{_current} = $value;
}

sub _store
{
    my ($self) = @_;

    if (!defined $self->c->session->{wizard}->{$self->_session_id})
    {
        $self->c->session->{wizard}->{$self->_session_id} = {};
    }

    return $self->c->session->{wizard}->{$self->_session_id};
}

sub _retrieve_wizard_settings
{
    my ($self) = @_;

    my $p = $self->c->request->parameters;

    return if $self->_session_id;

    # FIXME: this will break if the form has a name...
    return $self->_new_session unless $p->{wizard_session_id};

    $self->_session_id ($p->{wizard_session_id});

    $self->_current( $self->_store->{current} ) if defined $self->_store->{current};
}

sub _new_session
{
    my ($self) = @_;

    my $session_id = rand;
    while (defined $self->c->session->{wizard}->{$session_id})
    {
        $session_id = rand;
    }
    $self->c->session->{wizard}->{$session_id} = {};
    $self->_session_id( $session_id );

    $self->_store_wizard_settings;
}

sub _store_wizard_settings
{
    my ($self) = @_;

    $self->_store->{current} = $self->_current;
}

sub _load_form
{
    my ($self, $page, %args) = @_;

    my $form_name = "MusicBrainz::Server::Form::".$self->pages->[$page]->{form};
    Class::MOP::load_class($form_name);

    my $form;
    if (defined $args{init_object})
    {
        $form = $form_name->new (%args, ctx => $self->c );
    }
    else
    {
        $form = $form_name->new ( ctx => $self->c );
        $form->unserialize ( $args{serialized} ) if $args{serialized};
    }

    return $form;
}

1;