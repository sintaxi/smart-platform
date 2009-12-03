package RSP::Config::Host;

use feature qw(switch);

use Moose;
use File::Spec;
use File::Path qw(make_path);
use Try::Tiny;

has _config => (is => 'ro', required => 1, init_arg => 'config');
has _master => (is => 'ro', required => 1, init_arg => 'global_config', isa => 'RSP::Config');

# XXX - should this come from a role???
has js_engine => (is => 'ro', required => 1, isa => 'Str', lazy_build => 1);
sub _build_js_engine {
    my ($self) = @_;
    return $self->_config->{js_engine} // 'SpiderMonkey';
}

sub op_threshold { goto &oplimit }
has oplimit => (is => 'ro', isa => 'Int', lazy_build => 1);
sub _build_oplimit {
    my ($self) = @_;
    return $self->_config->{oplimit} ? $self->_config->{oplimit} : $self->_master->oplimit;
}

has should_report_consumption => (is => 'ro', isa => 'Bool', lazy_build => 1);
sub _build_should_report_consumption {
    my ($self) = @_;
    return $self->_config->{noconsumption} ? 0 : 1;
}

has entrypoint => (is => 'ro', isa => 'Str', default => 'main');

has extensions => (is => 'ro', lazy_build => 1, isa => 'ArrayRef[ClassName]');
sub _build_extensions {
    my ($self) = @_;
    my $extensions_string = $self->_config->{extensions} // '';
    my @extensions = map {
            'RSP::Extension::' .  $_;
        } split(/,/, $extensions_string);

    for my $class (@extensions){
        eval { Class::MOP::load_class($class) };
        die "Could not load extension '$class': $@" if $@;
    }

    my @parent_extensions = @{ $self->_master->extensions };
    return [@parent_extensions, @extensions];
}

has hostname => (is => 'ro', isa => 'Str', required => 1);

has actual_host => (is => 'ro', isa => 'Str', lazy_build => 1);
sub _build_actual_host {
    my ($self) = @_;
    return $self->_config->{alternate} ? $self->_config->{alternate} : $self->hostname;
}

has root => (is => 'ro', isa => 'ExistantDirectory', lazy_build => 1);
sub _build_root {
    my ($self) = @_;
    my $hostroot = $self->_master->hostroot;
    my $dir = File::Spec->catfile($hostroot, $self->actual_host);
    if(!-e $dir){
        try {
            make_path($dir);
        } catch {
            die "Unable to create hostdirectory '$dir': $@";
        }
    }
    return $dir;
}

has code => (is => 'ro', isa => 'ExistantDirectory', lazy_build => 1);
sub _build_code {
    my ($self) = @_;
    my $dir = File::Spec->catfile($self->root, qw(js));
    die "Code directory '$dir' does not exist" if !-d $dir;
    return $dir;
}

# XXX - make this an 'ExistantFile' type constraint?
has bootstrap_file => (is => 'ro', lazy_build => 1);
sub _build_bootstrap_file {
    my ($self) = @_;
    my $file = File::Spec->catfile($self->code, qw(bootstrap.js));
    return $file;
}

has alloc_size => (is => 'ro', lazy_build => 1, isa => 'Int');
sub _build_alloc_size {
    my ($self) = @_;
    return (1024 ** 2) * 2;
}

has log_directory => (is => 'ro', isa => 'ExistantDirectory', lazy_build => 1);
sub _build_log_directory {
    my ($self) = @_;
    my $dir = File::Spec->catfile($self->root, qw(log));
    if(!-e $dir){
        try {
            make_path($dir);
        } catch {
            die "Unable to create log directory '$dir': $@";
        }
    }
    return $dir;
}

# XXX - make this an 'ExistantFile' type constraint?
has access_log => (is => 'ro', lazy_build => 1);
sub _build_access_log {
    my ($self) = @_;
    my $logfile = File::Spec->catfile($self->log_directory, qw(access_log));
    return $logfile;
}

has web => (is => 'ro', lazy_build => 1, isa => 'ExistantDirectory');
sub _build_web {
    my ($self) = @_;
    my $dir = File::Spec->catfile($self->root, qw(web));
    die "Web directory '$dir' does not exist" if !-d $dir;
    return $dir;
}


sub file {
    my ($self, $type, $path) = @_;

    given($type){
        when('code') { $path = File::Spec->catfile( $self->code, $path); }
        when('web')  { $path = File::Spec->catfile( $self->web, $path); }
        default { die "Unknown file type '$type'"; }
    }

    return $path;
}


no Moose;
#__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME 

RSP::Config::Host - Configuration for RSP hosted applications

=head1 SYNOPSIS

  use RSP::Config::Host;
  my $conf = RSP::Config->new(config => { ... });

=head1 DESCRIPTION

This module provides an object encapsulation around the 'rsp.conf' to provide
a sanitized wrapper for use by RSP when dealing wit configuration for specific
hosted applications.

=head1 CONFIGURATION

  # contents of rsp.conf

  [host:exampleapp.smart.joyent.com]
  alternate=www.exampleapp.smart.joyent.com
  oplimit=50000

=head1 OPTIONS

For each [host:<hostname>] section, these are the available options:

=head2 extensions

This is a comma seperated list of extensions to load into the RSP hosted 
application.

=head2 oplimit

Each host can be individually configured with their own oplimits. See 
L<RSP::Config> for more detail.

=head2 alternate

TODO

=head2 root

You may configure a seperate path to use for this hosted application.

=head2 entrypoint

This is the name of the javascript function that should be called upon entry
into the Javascript interpreter.

=head2 noconsumption

This indicates wether resources consumed by this hosted application should be 
tracked.

=head1 METHODS

=head2 root

  my $path = $conf->root;

Returns an absolute path. Throws and exception if the path does not exist.

=head2 extensions

  my $extensions = $conf->extensions;
  print join ', ', @$extensions;

Returns an arrayref of full class names for listed extensions. It will also load
those classes if not already loaded. This list will also include extensions
loaded by RSP application as well the ones specific to this hosted application.

=head2 oplimit

  my $limit = $conf->oplimit;

Returns the configured oplimit as an integer for this hosted application. It
will default to the global RSP oplimit.

=head2 should_report_consumption

  my $reporting_on = $conf->should_report_consumption;

This returns a boolean as to wether resources consumed by this hosted application
should be tracked.

=head2 hostname

  my $name = $conf->hostname;
  
This returns the hostname configured for this hosted application.

=head2 actual_host

TODO

=head2 code

  my $code_path = $conf->code;

This returns an absolute path to the directory that contains the source code
for this hosted application.

=head2 bootstrap_file

  my $file = $conf->bootstrap_file;

This returns the absolute path to the file that should be executed once running
the Javascript interpreter.

=head2 alloc_size

  my $size = $conf->alloc_size;

TODO

=head2 log_directory

  my $path = $conf->log_directory;

This is the absolute path of the directory to use for this hosted applications
log files.

=head2 web

  my $path = $conf->web;

This returns the absolute path that contains static files to be served for this
hosted application.

=head2 access_log

  my $filepath = $conf->access_log

This returns the absolute path to the file to use for access logging.

=head2 file

  my $filepath = $conf->file(code => 'foo.js');

  -- or --

  my $filepath = $conf->file(web => 'foo.png');

This returns the absolute path to a file within either the source code or
static file directories.

=head1 AUTHOR

Scott McWhirter, C<<scott DOT mcwhirter -at- joyent DOT com>>

=head1 COPYRIGHT

Copyright (c) 2009, Joyent Inc.

=head1 LICENCE

Please refer to the LICENCE file in this distribution for details.

=cut
