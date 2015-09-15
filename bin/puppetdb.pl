#!/usr/bin/perl

=head1 NAME

puppetdb - Query the puppetdb for resources

=head1 SYNOPSIS

puppetdb [options]

 Options:
  --type        resource type
  --exported    exported resources only
  --url         puppetdb api url
  --template    display template (doesn't do anything yet)
  --format      output format
  --tag         filter by tag
  --individual  one resource per template
  --debug       show debug output
  --help        brief help message
  --man         long help message

=head1 OPTIONS

=over 8

=item B<--type>

The resource type you wish to query. Some useful things to try are 
B<nagios_host> and B<nagios_service>.

=item B<--exported>

Limit the output to exported resources only.

=item B<--url>

The url of your local puppetdb server.

=item B<--template>

The template to use to render the queried resource type. If not specified, one
of the built in templates will be used. These templates try their best to be
useful, but may not fit your needs.

=item B<--format>

The outut format to use. Defaults to 'dumper', which simply serializes the
resources in Data::Dumper format.

=item B<--individual>

Render a template for each individual resource. This will increase runtime
significantly, but allows you to use a relatively simple template.

=item B<--tag>

A tag to filter on. For example, --tag magical will find all resources of the
given type which are tagged as magical.

=back

=cut

use strict;
use warnings;
use feature qw/say/;
use Mojo::Template;
use Mojo::UserAgent;
use Getopt::Long;
use Mojolicious::Renderer;
use Pod::Usage;
use JSON::MaybeXS qw(encode_json);

my %options = (
  'format' => 'dumper',
);

GetOptions( \%options,
  "url=s", "debug", "type=s",
  "template=s", "format=s",
  "individual",  "tag=s", 
  "exported", "help", "man"
) || pod2usage(2);

pod2usage(1) if $options{help};
pod2usage(-verbose => 2) if $options{man};
pod2usage({
    -message => q{I need a resource type to proceed.},
    -exitval => 1  ,
    -verbose => 0
}) unless $options{type};

pod2usage({
    -message => q{I need an url to proceed.},
    -exitval => 1  ,
    -verbose => 0
}) unless $options{url};


# Now, let's get some data to play with
my $ua = Mojo::UserAgent->new;
my $endpoint = $options{url} . '/pdb/query/v4/resources/';

# Build a simple and query
my $query = [];
push @$query, ["=", "type", ucfirst $options{type}];
push @$query, ["=", "tag", $options{tag}] if $options{tag};
push @$query, ["=", "exported", \1] if $options{exported};

if (scalar @$query < 2) {
  $query = $query->[0];
} else {
  unshift @$query, "and";
}

my $encoded_query = encode_json($query);
say '# query: ', $encoded_query if $options{debug};

my $result;

my $rq = $ua->get(
  $endpoint => {Accept => 'application/json'} => 
  form => {query => $encoded_query, order_by => '[{"field": "certname"},{"field": "title"}]'}
);
if (my $res = $rq->success) {
  $result = $res->json;
} else {
  my $err = $rq->error;
  die "$err->{code} response: $err->{message}" if $err->{code};
  die "Connection error: $err->{message}";
}

# Let's decide what template to use...
my $renderer = Mojolicious::Renderer->new;
my $template;

my $prefix = "resources";
$prefix = "resource" if $options{individual};

$template = $renderer->get_data_template({
  template => "${prefix}/". lc $options{type},
  format   => $options{format},
  handler  => 'ep'
});

if(! $template) {
  # Clearly, all our attempts to get a sensible template failed, so we fall
  # back on a default template.
  $template = $renderer->get_data_template({
    template => "resources/default",
    format   => 'dumper',
    handler  => 'ep'
  });
} 

my $te = Mojo::Template->new;

if ($options{individual}) {
  foreach (@$result) {
    say $te->render($template, $_);
  }
} else {
  say $te->render($template, $result);
}

__DATA__
@@resources/default.dumper.ep
% use Data::Dumper;
% my $resource = shift;
%= Dumper($resource)

@@resources/nagios_host.nagios.ep
% my $resources = shift;
% my %puppetmeta = map { $_ => 1 } qw/require before subscribe notify audit loglevel noop schedule stage tag target ensure/;
% foreach my $resource (@$resources) {
define host {
  host_name <%= $resource->{title} %>
%   while (my ($key, $value) = each %{$resource->{parameters}}) {
%     next if $puppetmeta{$key};
%     if (ref($value) eq "ARRAY") {
  <%= $key %> <%= join(',', @$value) %>
%     } else {
  <%= $key %> <%= $value %>
%     }
%   }
}
% }

@@resources/nagios_service.nagios.ep
% my $resources = shift;
% my %puppetmeta = map { $_ => 1 } qw/require before subscribe notify audit loglevel noop schedule stage tag target ensure/;
% foreach my $resource (@$resources) {
define service {
%   while (my ($key, $value) = each %{$resource->{parameters}}) {
%     next if $puppetmeta{$key};
%     if (ref($value) eq "ARRAY") {
  <%= $key %> <%= join(',', @$value) %>
%     } else {
  <%= $key %> <%= $value %>
%     }
%   }
}
% }

@@resource/nagios_host.nagios.ep
% my $resource = shift;
% my %puppetmeta = map { $_ => 1 } qw/require before subscribe notify audit loglevel noop schedule stage tag target ensure/;
define host {
  host_name <%= $resource->{title} %>
% while (my ($key, $value) = each %{$resource->{parameters}}) {
%   next if $puppetmeta{$key};
%   if (ref($value) eq "ARRAY") {
  <%= $key %> <%= join(',', @$value) %>
%   } else {
  <%= $key %> <%= $value %>
%   }
% }
}

@@resource/nagios_service.nagios.ep
% my $resource = shift;
% my %puppetmeta = map { $_ => 1 } qw/require before subscribe notify audit loglevel noop schedule stage tag target ensure/;
define service {
% while (my ($key, $value) = each %{$resource->{parameters}}) {
%   next if $puppetmeta{$key};
%   if (ref($value) eq "ARRAY") {
  <%= $key %> <%= join(',', @$value) %>
%   } else {
  <%= $key %> <%= $value %>
%   }
% }
}

