#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Parallel::ForkManager;
use BerkeleyDB;
use FindBin qw/$Bin/;
use Data::Dumper;
use File::Spec;

my $pm = new Parallel::ForkManager(4);

my $tmp_dir = File::Spec->tmpdir();
my $env = new BerkeleyDB::Env
    -Home   => $tmp_dir,
    -Flags  => DB_CREATE|DB_INIT_CDB|DB_INIT_MPOOL
        or die "cannot open environment: $BerkeleyDB::Error\n";

my $berkeleydb_temp_file = "$Bin/tmp.berkeleydb"; # temp file for BerkeleyDB
unlink($berkeleydb_temp_file) if -e $berkeleydb_temp_file;
my $db = tie my %data, 'BerkeleyDB::Hash',
    -Filename => $berkeleydb_temp_file,
    -Flags    => DB_CREATE,
    -Env      => $env
        or die "Cannot create file: $! $BerkeleyDB::Error\n";

foreach my $i (1 .. 1000) {
    $pm->start and next; # do the fork
    
    my $lock = $db->cds_lock();
    $data{$i} = $i * 2;
    $db->db_sync();
    $lock->cds_unlock();
    
    $pm->finish; # Terminates the child process
}

$pm->wait_all_children;

is(scalar(keys %data), 1000);

unlink($berkeleydb_temp_file);

done_testing;