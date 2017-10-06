# POE6::Tiny

POE6::Tiny-0.0.3. A simple fork/migration of POE::Kernal into Perl 6


## Synopsis

This module is a 'Tiny' Perl6 fork of POE using Ingo's POE-0.0.1 module.
It is configured for POST, YIELD and DELAY method calls. The method calls can be
made directly to the kernel or from a registered session object.
The POE::Kernal is created with a very simple session.
It runs the sample code (Tiny-examples), but has only preliminary session handling

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
## Additional Info

Version 0.0.3 uses Roles to bring in common methods from Kernel::Main and POE6::Session.
Most of the methods are in the role definitions. So your Session class definition looks like
'class MySession does POE6::Session'. The POE6::Kernel is extensible and offers an option
for custom startup options/methods - though, I'm not sure that is a good idea. 

Two processes have been added. In the kernel, it is possible to register and use a dedicated
messaging channel between [session] objects. The intent is to minimuze much of the setup to
pass small data parts around an app. After the "dchannel" is registered, then the dchannel is called
with the dchannel id and a message hash. The channel is async and assumes that the caller and callee
operate independently. If the message requires a response, a "backcall" can be configured to
return a message to a receiving option within the caller.

A process has been added to the Session role to provide a timeout function for the dedicated
channel process. It times out the response of a function that was assigned to provide a response
from the callee to the caller. Upon timeout, a default message is sent to the caller indicating 
failure and any possible response from the function is trapped and discarded. This may have uses elsewhere.

The process method is "waitontoken()". It takes a token key, a dispatch and responder option, and the timeout to perform
an async response timeout. The easiest token to use is '$token_key = now'. Any non-conflicting ID will work. This method 
is transparent to the dedicated channel registration and use.

Using a dedicated channel:
```perl6
## some stuff to pass around
my @a = (a,b);
my %h = (a => 1, b => 2);
my $message = { i_mess => 1, mess => 'dchannel message', a_mess => item(@a), h_mess => item(%h) };

## add some aliases to the sessions to make referencing easier
$session3.session_alias(alias => 'tweedle');

## and/or
my $session4 = MySession.new( poe_kernel => $POE::Kernel, alias => 'dee', set_session_messaging => 1  );
    ## NOTE that the reactors need to be configured within the 'to' session object in order to receive
	## dchannel messages...so 'set_session_messaging => 1' is needed.
## also, can use
$session3.set_session_messaging(1);


## register a dedicated channel. It returns the dchannel_id used for calling the dchannel.
my $dchann_id = $POE::Kernel.register_dchannel( session_from_key => 'tweedle', session_to_key => 'dee', destination => 'new_call' );

## send a message (new_call should print a default message to the screen).
$POE::Kernel.dchannel_message( dchannel_id => $dchann_id, message => $message );

## register a dedicated channel with a response and timeout. If the timeout is 0, then the response will be processed
## whenever the message is eventually sent. The timeout provides an indication of process failure.
my $dchann2_id = $POE::Kernel.register_dchannel( 
					session_from_key => 'tweedle',
					session_to_key => 'dee', 
					destination => 'sync_call',
					responder => 'send_back_on_dchannel',
					await_response => 1,
					timeout => 2,
					);
					
$POE::Kernel.dchannel_message( dchannel_id => $dchann2_id, message => $message );

```

If you find a reason to use run a long lived session, then...

```perl6
$POE::Kernel.run_loop();
```
...enter the main runloop. Good luck!

Note. The global variable $POE::Kernal should be created outside of the class package 
to ensure the namespace is populated. Otherwise a 'Cannot find symbol' error may occur.

## Examples

Look in Tiny-examples.pl6.

## Description

Author credits: 
    (Perl6) POE-0.0.1, Ingo Blechschmidt << <iblech@web.de> >>
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


## Rationale
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

