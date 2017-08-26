# POE6::Tiny

A simple fork/migration of POE::Kernal into Perl 6


## Synopsis

This module is a 'Tiny' Perl6 fork of POE using Ingo's POE-0.0.1 module
As of this point, a POE::Kernal is created with a very simple session.
It runs the sample code, but has only preliminary configuration for POST, YEILD and DELAY events.

```perl6
use POE6::Tiny;

class MySession is POE6::Session {
  method dispatch(Str $event, *@args) {
      given $event {
          when "say_hello" {
              return "Hello, @args[0]!";
          }
#          ...;
      }
  }
}

# Create a global POE::Kernel object.
our $POE::Kernel = POE6::Kernel.new;

# Create a session object
my $session = MySession.new;

# Use the session object to do something you coded into MySession
say $POE::Kernel.post($session, "say_hello", "Poe Poe");

```

At your own risk, you can try

```perl6
$POE::Kernel.run();
```
and enter the main runloop. Good luck!

Note. The global variable $POE::Kernal should be created outside of the class package to ensure the namespace is populated. Otherwise a 'Cannot find symbol' error may occur.

No examples yet.

## Description

Author credits: (Perl6) POE-0.0.1, Ingo Blechschmidt << <iblech@web.de> >>
                (Perl5) POE-1.367, Rocco Caputo << <rcaputo@cpan.org> >>  http://poe.perl.org/
 
The intent is to satisfy simple POE needs in Perl6, not to re-write POE in Perl 6.
Therefore this module will not have all of the bookkeeping embedded within POE,
The basic functionalities intended are stable POST, YIELD, and DELAY events,
and integration of a HTTP::Server.

This code is nearly an identical re-write of POE-0.0.1. The syntax has been updated to run
on the latest version of Perl 6 (2017-07).

POE is a Perl framework for reactive systems and multitasking networked applications. 
See [poe.perl.org](http://poe.perl.org) for more information about POE.


## Installation

If you are using Rakudo Perl 6 with ```zef``` installed then you
should be able to install this with:

    zef install POE6::Tiny

If you want to install this from a local copy substitute the distribution
name for the path to the local copy.

## Support

If it works, you are good to go.


## Copyright and Licence

This is free software, please see the [LICENCE](LICENCE) file in the
distribution.

© Ultra-Gitsome 2017

