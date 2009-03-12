var Resource = function( typename, watches ) {

  if (!watches) watches = {};

  // the constructor for the object.
  // add a creation date and an id.  Of course,
  // the id isn't set in stone until the object is
  // saved to the datastore, and then it is essentially
  // immutable.
  var theType = function() {
    this.created = new Date().getTime();
    this.id      = system.uuid();
    this._set_watches();
    if ( watches['@constructor'] )
      watches['@constructor'].apply(this, arguments);
  };

  // if the object is transient then it only goes into
  // the memory cache.
  theType.transient = false;

  theType.search = function( aQuery, someOptions ) {
    if ( theType.transient ) throw new Error("cannot search for transient objects");
    return system.datastore.search(typename, aQuery, someOptions).map( function( anObject ) {
      anObject.__proto__ = theType.prototype;
      if ( watches['@get'] ) watches['@get'].apply(anObject, []);
      anObject._set_watches();
      return anObject;
    });
  };

  // remove an object from the datastore, but as a class
  // method instead of an object method.
  theType.remove = function( anId ) {
    theType.get( anId ).remove();
  };

  // gets an object from the datastore.
  theType.get = function( anId ) {
    var theObject = system.datastore.get(typename, anId);
    theObject.__proto__ = theType.prototype;
    if ( watches['@get'] ) watches['@get'].apply(theObject, []);
    theObject._set_watches();
    return theObject;
  };

  theType.prototype._set_watches = function() {
    for ( var prop in watches ) {
      if ( !prop.match(/^\@/) )
	this.watch( prop, watches[prop] );
    }
  };

  theType.prototype._unset_watches = function() {
    for ( var prop in watches ) {
      this.unwatch( prop );
    }
  };

  theType.prototype.remove = function() {
    system.datastore.remove(typename, this.id );
    if ( watches['@remove'] )
      watches['@remove'].apply(this,[]);
  };

  theType.prototype.save = function() {
    this.updated = new Date().getTime();
    system.datastore.write(typename, this, theType.transient);
    if ( watches['@save'] )
      watches['@save'].apply(this, []);
  };

  theType.typename = typename;

  if (!Resource.types) Resource.types = [];
  Resource.types.push( typename );

  if (!Resource.typemap) Resource.typemap = {};
  Resource.typemap[typename] = theType;

  return theType;
};
