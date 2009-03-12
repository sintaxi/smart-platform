
system.console.log("setting up sammy object..");
var Sammy = {
  handles: {
    'GET':    [],
    'PUT':    [],
    'POST':   [],
    'DELETE': [],
    'before': [],
    'error':  function() {
      return [
	500,
	"Server Error",
	['Content-Type', 'text/html'],
	"There was an error: " + Sammy.theObject.error
      ];
    }
  },

  'run_error_handler': function( anError ) {
    Sammy.theObject.error = anError;
    return Sammy.handles.error.apply( Sammy.theObject, [] );
  },

  run_handle: function( aHandle, someArgs ) {
    if (!someArgs) someArgs = [];
    var result = aHandle.apply( Sammy.theObject, someArgs );
    return result;
  },

  match_primitive: function( pattern, fn ) {
    if ( typeof( pattern ) == 'string' && pattern == Sammy.theObject.request.uri ) return Sammy.run_handle( fn );
  },

  match_object: function( object, fn ) {
    if ( object instanceof RegExp ) {
      var matches = Sammy.theObject.request.uri.match( object );
      if ( matches ) {
	matches.shift();
	return Sammy.run_handle( fn, matches );
      }
    }
  },

  match: function( thing, fn ) {
    var result;
    if ( thing instanceof Object ) {
      result = Sammy.match_object( thing, fn );
    } else {
      result = Sammy.match_primitive( thing, fn );
    }
    return result;
  },

  Pass: function() {},

  Halt: function( aCode, aMessage ) {
    this.code    = 500;
    this.message = "Server Error";
    this.content = "There was an error processing your request.";
    if ( aCode && aMessage ) {
      this.code    = aCode;
      this.content = aMessage;
    } else if ( aCode && !aMessage ) {
      this.content = aCode;
    }
  },

  Redirect: function( aLocation ) {
    this.location = aLocation;
  },

  Created: function( aLocation ) {
    this.location = aLocation;
  }

};

system.console.log("set up sammy object");

function main( aRequest ) {
  var thisObj = {
    request: aRequest
  };
  Sammy.theObject = thisObj;
  try {
    var file = system.filesystem.get("/public" + aRequest.uri);
    if ( file )
      return [ 200, 'Ok', ['Content-Type', file.mimetype], file ];
    else throw new Error("no such file");
  } catch( e ) {
    var method  = aRequest.method;
    var handles = Sammy.handles[ method ];

    for each ( var handle in Sammy.before ) {
      handle.apply( thisObj, [] );
    }

    for each ( var handle in handles ) {
      var result;
      var pattern = handle.pattern;
      var fn      = handle.fn;

      try {
	result = Sammy.match( pattern, fn );
	if ( result ) {
	  return [ 200, 'Ok', ['Content-Type', 'text/html'], result ];
	}
      } catch(e) {
	if ( e instanceof Sammy.Halt ) { return [ e.code, e.message, ['Content-Type', 'text/html'], e.content ]; }
	else if ( e instanceof Sammy.Created ) return [ 201, "Created", ['Location', e.location], null ];
	else if ( e instanceof Sammy.Redirect ) return [ 301, "Moved Permanently", ['Location', e.location], null ];
        else if ( e instanceof Sammy.Pass ) { /* do nothing... */ }
	else {
	  system.console.log("we need to run the error handler");
	  try {
	    return Sammy.run_error_handler( e );
	  } catch( final_e ) {
	    // okay, we're really screwed, the custom error handler didn't respond with anything, so now we're going for
	    // broke.
	    return [ 500, "Server Error", [ 'Content-Type', 'text/html' ], <html>
	        <head>
		  <title>Server Error</title>
		</head>
	        <body>
		  <h1>Server Error</h1>
		  <p>Not only did the code break, but the custom error handler broke as well.</p>
		  <p>The error handler raise the following uncaught exception: {final_e.message}</p>
		  <p>The original error was {e.message}</p>
	        </body>
	      </html>
	    ];
	  }
	}
      }
    }
  }
  system.console.log("we went too far, 404 time.");
  return [
    404,
    "Not Found",
    ['Content-Type', 'text/html'],
    <html>
      <head>
        <title>Not Found</title>
      </head>
      <body>
        <h1>Not Found</h1>
        <p>We could not find the page {aRequest.uri}</p>
      </body>
   </html>
  ];
};

function template ( aFile ) {
  system.use("com.github.ashb.Template");
  var theFile = system.filesystem.get( aFile );
  if ( theFile ) {
    var tt = new Template({});
    return tt.process( theFile.contents, Sammy.theObject );
  } else {
    throw new Error("404!");
  }
}

function enable( aThing ) {
  Sammy[aThing].enable();
}

function GET ( aPattern, aFunction ) {
  Sammy.handles.GET.push( { pattern: aPattern, fn: aFunction } );
}

function POST ( aPattern, aFunction ) {
  Sammy.handles.POST.push( { pattern: aPattern, fn: aFunction } );
}

function PUT ( aPattern, aFunction ) {
  Sammy.handles.PUT.push( { pattern: aPattern, fn: aFunction } );
}

function DELETE ( aPattern, aFunction ) {
  Sammy.handles.DELETE.push( { pattern: aPattern, fn: aFunction } );
}

function before( aFunction ) {
  Sammy.handles.before.push( aFunction );
}

function halt( aCode, aMessage ) {
  throw new Sammy.Halt( aCode, aMessage );
}

function pass() {
  throw new Sammy.Pass();
}

function redirect( aLocation ) {
  throw new Sammy.Redirect( aLocation );
}

function created( aLocation ) {
  throw new Sammy.Created( aLocation );
}

function error( aFunction ) {
  Sammy.handles.error = function() {
    return [ 500, "Server Error", ['Content-Type', 'text/html'], aFunction.apply( this, [] ) ];
  };
}
