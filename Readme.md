# POE6::Tiny

POE6::Tiny-0.0.2. A simple fork/migration of POE::Kernal into Perl 6


## Synopsis

This module is a 'Tiny' Perl6 fork of POE using Ingo's POE-0.0.1 module.
It is configured for POST, YIELD and DELAY method calls. The method calls can be
made directly to the kernel or from registered session object.
The POE::Kernal is created with a very simple session.
It runs the sample code (Tine-examples), but has only preliminary session handling

```perl6
use POE6::Tiny;

class MySession does POE6::Session {
  method dispatch(Str $event, *@args) {
      given $event {
          when "say_hello" {
              return "Hello, @args[0]!";
          }
#          ...;
      }
  }
  
  ## the 'dispatch_sig' method returns a boolean value
  method dispatch_sig(Str $event, *@args) {
      given $event {
          when "say_hello" {
              say "Hello, @args[0]!";
              return;
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
## Note that this call has an implicit sync'ed return,
say $POE::Kernel.post($session, "say_hello", "Poe Poe");

## Create another session
my $session2 = MySession.new;

## Execute a 'yield' call to the kernel with the session object
say $POE::Kernel.yield($session2, "say_hello", "Poe Poe too");
	## Note: the session callback will print the arg [Poe Poe too] to 
	## the screen, but the 'yield' call will return True. So the
	## above statement will print "True" when result returns.

	## Create yet another session
my $session3 = MySession.new;

## Add the session to the kernel environment
$POE::Kernel.add_session( $session3 );
	## or, my $session3 = MySession.new( poe_kernel => $POE::Kernel );

## Now execute a pass-thru method on the session object.
say $session3.yield("say_hello", "Poe Poe too");

## and...a 'delay' method, with 'timeout' argument
say $session3.delay("say_hello", 3, "Poe Poe too");


```

If you find a use run a long lived session, then...

```perl6
$POE::Kernel.run_loop();
```
...enter the main runloop. Good luck!

Note. The global variable $POE::Kernal should be created outside of the class package 
to ensure the namespace is populated. Otherwise a 'Cannot find symbol' error may occur.

## Examples

Look in Tiny-examples.pl6.

## Description

Author credits: (Perl6) POE-0.0.1, Ingo Blechschmidt << <iblech@web.de> >>
                (Perl5) POE-1.367, Rocco Caputo << <rcaputo@cpan.org> >>  http://poe.perl.org/
 
The intent is to satisfy simple POE needs in Perl6, not to re-write POE in Perl 6.
Therefore this module will not have all of the bookkeeping embedded within POE,
The basic functionalities intended are stable POST, YIELD, and DELAY events,
and intra-session communitation channels. 
Also planned is an integration of Cro:: services - tho, that work has not be fully
researched :-)

This code started from Ingo's POE-0.0.1 code. The syntax was been updated to run
on the (2017-07) version of Perl 6. A relatively simple run_loop is available.

Base Methods:
POST: A synchronise call to the kernel to execute a callback within the session object.
Has an implicit sync'ed return value.

YIELD: An aysynchronise call to the kernel to execute a callback within the session object.
Uses a channel to a react[or] state that is triggered by an emitted key. The caller is not
linked to the callback, so no value is returned directly.

DELAY: An aysynchronise call to the kernel to execute a timeout delayed callback within
the session object. Uses a channel to a react[or] state that is triggered by an emitted key.
The caller is not linked to the callback, so no value is returned directly.


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

