OAuth2
======

OAuth2 frameworks for **OS X** and **iOS** written in Swift.
This is more of an academic exercise and very much WiP.
Here is a very nice explanation of OAuth's basics: [The OAuth Bible](http://oauthbible.com/#oauth-2-three-legged).

The code in this repo requires Xcode 6 to compile and will run on OS X 10.9+ or iOS 7+.

Flows
-----

#### Code Grant

For a full OAuth 2 code grant flow you want to use the `OAuth2CodeGrant` class.
This flow is typically used by applications that can guard their secrets, like server-side apps, and not in distributed binaries.

#### Implicit Grant

An implicit grant is suitable for apps that are not capable of guarding their secret, such as distributed binaries or client-side web apps.
Use the `OAuth2ImplicitGrant` class to receive a token and perform requests.


Playground
----------

Instead of a sample app there is a Playground.
However, because it's not currently possible to import custom code into playgrounds it's not yet working.
