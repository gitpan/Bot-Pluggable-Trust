package Bot::Pluggable::Trust::SQLite;
$VERSION = 0.04;
use strict;
use warnings;
use base qw(Bot::Pluggable::Trust);

=pod

=head1 NAME 

Bot::Pluggable::Trust::SQLite - A Subclass of Bot::Pluggable::Trust

=head1 SYNOPSIS

my $trust = new Bot::Pluggable::Trust::SQLite(
    owner=>"perigrin",
    delay => 5,
    lag => 20,
    dbfile=>"Bender.sqlite",
    DEBUG=>1,
);

=head1 DESCRIPTION

This is just like Bot::Pluggable::Trust except that it uses SQLite to    
provide for the backend userdata.

=cut

use DBI;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{_DBH_} = DBI->connect("dbi:SQLite:dbname=$$self{dbfile}","","");
    $self->load_schema;
    return $self;
}

sub load_schema {
    my ($self) = @_;   
    my $query = qq{ SELECT name FROM sqlite_master
                    WHERE type='table'
                    AND ( name = 'channel'
                       OR name = 'voice'
                       OR name = 'ops'
                        )
                    ORDER BY name
                  };
    return if defined @{ $self->{_DBH_}->selectall_arrayref($query) }[0];
    my @new_tables = (
        qq{CREATE TABLE ops (
            name TEXT,
            channel TEXT,
            UNIQUE(name, channel)
        )},
        qq{CREATE TABLE voice (
            name TEXT,
            channel TEXT,
            UNIQUE(name, channel)
        )},
        qq{CREATE TABLE channel (
            name TEXT UNIQUE
        )},
    );   
    for my $query (@new_tables) {
        $self->{_DBH_}->do($query) or die "Can't Create Table: $query";
    }
    return;
}

sub load_channels {
    my $self = shift;
    my $channels = {};
    my $query = qq{ SELECT name FROM channel };
    my $targets = $self->{_DBH_}->selectall_arrayref($query); 
        if ($DBI::errstr){ die "$DBI::errstr - $query"}
    for my $target (@$targets) {
        my $channel = $$target[0];
        print STDERR "Loading $channel\n" if $self->{DEBUG};
        $channels->{$channel} = {};
    }
    $self->Channels($channels);
}

sub load_ops {
    my ($self, $channel) = @_;
    my $channels = $self->Channels;
    $channels->{$channel}{ops} = {};
    my $query = qq{ SELECT name 
                    FROM ops 
                    WHERE channel = '$channel' };
		 my $users = $self->{_DBH_}->selectall_arrayref($query); 
        if ($DBI::errstr){ die "$DBI::errstr - $query"};
    for my $user (@$users) {
        print STDERR "Loading $channel +o $$user[0]\n" if $self->{DEBUG};
        $channels->{$channel}{ops}{$$user[0]}++
    }
    $self->Channels($channels); 
}

sub load_voice {
    my ($self, $channel) = @_;
    my $channels = $self->Channels;
    $channels->{$channel}{voice} = {};    
    my $query = qq{ SELECT name 
                    FROM voice  
                    WHERE channel = '$channel' };
		 my $users = $self->{_DBH_}->selectall_arrayref($query); 
        if ($DBI::errstr){ die "$DBI::errstr - $query"}
    for my $user (@$users) {
        print STDERR "Loading $channel +v $$user[0]\n" if $self->{DEBUG};
        $channels->{$channel}{voice}{$$user[0]}++
    }
    $self->Channels($channels);
}

sub save_channels {
    my ($self) = @_;
    for my $channel (keys %{ $self->Channels  }) {
        print STDERR "Saving $channel\n" if $self->{DEBUG};
        my $query = qq{ REPLACE INTO channel(name) VALUES('$channel') };
        die "$query" unless $self->{_DBH_}->do($query); 
    }
}

sub save_ops {
    my ($self, $channel) = @_;
    my $channels = $self->Channels;
    for my $user (keys %{ $channels->{$channel}{ops} }) {
        print STDERR "Saving $channel +o $user\n" if $self->{DEBUG};
        my $query = qq{ REPLACE INTO ops(name, channel) VALUES('$user', '$channel') };
        die "$query" unless $self->{_DBH_}->do($query);
    }
}

sub save_voice {
    my ($self, $channel) = @_;
    my $channels = $self->Channels;
    for my $user (keys %{ $channels->{$channel}{voice} }) {
        print STDERR "Saving $channel +v $user\n" if $self->{DEBUG};
        my $query = qq{ REPLACE INTO voice(name, channel) VALUES('$user', '$channel') };
        die "$query" unless $self->{_DBH_}->do($query);
    }
}

sub remove_op {
    my ($self, $target, $channel) = @_;
    for my $query (qq{DELETE FROM ops WHERE name = '$target'}) {  
        print "Removing op $target $channel";
        $self->{_DBH_}->do($query); 
    }
    my $channels = $self->Channels;
    delete $channels->{$channel}{ops}{$target};
    delete $channels->{$channel}{voice}{$target} if $channels->{$channel}{voice}{$target};
    $self->Channels($channels);
    $self->save;
}

sub remove_voice {
    my ($self, $target, $channel) = @_;
    for my $query (qq{DELETE FROM voice WHERE nick = '$target'}) {  
        print "Removing voice $target $channel";
        $self->{_DBH_}->do($query);
    }
    my $channels = $self->Channels;
    delete $channels->{$channel}{voice}{$target};
    $self->Channels($channels);
    $self->save;
}

sub leave_channel {
    my ($self, $channel) = @_;
    for my $query ( 
         qq{DELETE FROM channel WHERE name = '$channel'},
         qq{DELETE FROM ops WHERE channel = '$channel'},
         qq{DELETE FROM voice WHERE channel = '$channel'},
     ) {  
         print "Removing channel $channel";
         $self->{_DBH_}->do($query);  
     }
    $self->{_BOT_}->part($channel);
    my $channels = $self->Channels();
    delete $channels->{$channel};
    $self->Channels($channels);
    $self->save;
}

1;
__END__