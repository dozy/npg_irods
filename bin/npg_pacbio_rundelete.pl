#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw[$Bin];
use lib (-d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib");
use Getopt::Long;
use Log::Log4perl qw[:levels];
use Pod::Usage;
use Readonly;

use WTSI::DNAP::Warehouse::Schema;
use WTSI::NPG::DriRODS;
use WTSI::NPG::HTS::PacBio::Sequel::RunDeleteMonitor;

our $VERSION = '';

Readonly::Scalar my $DEFAULT_INTERVAL_DAYS   => 14;
Readonly::Scalar my $DEFAULT_OLDER_THAN_DAYS => 180;

my $api_uri;
my $collection;
my $check_format = 1;
my $debug;
my $dry_run = 1;
my $interval = $DEFAULT_INTERVAL_DAYS;
my $local_path;
my $log4perl_config;
my $older_than = $DEFAULT_OLDER_THAN_DAYS;
my $verbose;

GetOptions('api-uri|api_uri=s'          => \$api_uri,
           'check-format|check_format!' => \$check_format,
           'collection=s'               => \$collection,
           'debug'                      => \$debug,
           'dry-run|dry_run!'           => \$dry_run,
           'help'                    => sub {
             pod2usage(-verbose => 2, -exitval => 0);
           },
           'interval=i'                 => \$interval,
           'local-path|local_path=s'    => \$local_path,
           'logconf=s'                  => \$log4perl_config,
           'older-than|older_than=i'    => \$older_than,
           'verbose'                    => \$verbose);


if ($log4perl_config) {
  Log::Log4perl::init($log4perl_config);
}
else {
  my $level = $debug ? $DEBUG : $verbose ? $INFO : $WARN;
  Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                            level  => $level,
                            utf8   => 1});
}

if (not $local_path) {
  pod2usage(-msg     => 'A local-path argument is required',
            -exitval => 2);
}

my $irods     = WTSI::NPG::DriRODS->new;
my $wh_schema = WTSI::DNAP::Warehouse::Schema->connect;

my @init_args = (check_format       => $check_format,
                 dry_run            => $dry_run,
                 irods              => $irods,
                 local_staging_area => $local_path,
                 interval           => $interval,
                 mlwh_schema        => $wh_schema,
                 older_than         => $older_than,
                 );

if ($collection) {
  push @init_args, dest_collection => $collection;
}

if($api_uri) {
  push @init_args, api_uri => $api_uri;
}

my $deletable = WTSI::NPG::HTS::PacBio::Sequel::RunDeleteMonitor->new(@init_args);

my ($num_runs, $num_processed, $num_deleted, $num_errors) = $deletable->delete_runs;

my $log = Log::Log4perl->get_logger('main');
$log->level($ALL);

my $output = qq{Considered $num_runs, processed $num_processed,}.
    qq{ deleted $num_deleted with $num_errors errors};

($num_errors == 0) ? $log->info($output) : $log->logcroak($output);


=head1 NAME

npg_pacbio_rundelete

=head1 SYNOPSIS

npg_pacbio_rundelete --local-path </path/to/staging/area>
  [--api-uri] [--check-format] [--debug] [--dry-run] [--interval days] 
  [--logconf file] [--older-than days] [--verbose]

 Options:
  --api-uri
  --api_uri       Specify the server host and port. Optional,
                  defaults to localhost:8071
  --check-format
  --check_format  Enable runfolder format checking for standard production
                  areas. Optional, defaults to true.  
  --collection    The destination collection in iRODS. Optional,
                  defaults to /seq/pacbio/.
  --debug         Enable debug level logging. Optional, defaults to false.
  --dry-run
  --dry_run       Enable dry-run mode. Optional, defaults to true.
  --help          Display help.
  --interval      Interval of time in days for run deletion. 
                  Optional, defaults to 14.
  --local-path
  --local_path    The path to the local filesystem where result data
                  are staged for loading into iRODS. At lease one 
                  path is required.
  --logconf       A log4perl configuration file. Optional.
  --older-than
  --older_than    Only consider runs older than a specified number of 
                  days. Optional defaults to 180 days. 
  --verbose       Print messages while processing. Optional.


=head1 DESCRIPTION

Looks for runs between an interval (default 14 days) a specified number of 
days ago (default 180 days) and deletes run folders which are determined 
to have been correctly uploaded to iRODS.

=head1 SYNOPSIS


=head1 AUTHOR

=head1 COPYRIGHT AND DISCLAIMER

Copyright (C) 2020 Genome Research Limited. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the Perl Artistic License or the GNU General
Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
