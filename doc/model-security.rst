==============
Model Security
==============

.. default-domain:: rb
.. highlight:: ruby

Through the module :mod:`ModelSecurity`, *AccessControl* introduces
modifications to :class:`ActiveRecord::Base` to allow security to be
implemented at the module level.  This module modifies the behaviour of
:meth:`ActiveRecord::Base#find`.  It will filter out every record that the
user has no permission to see.

Restriction by default
======================

In order to a record to be returned by
:meth:`ModelSecurity::ClassMethods#find` or variations, the user must have all
permissions returned by
:meth:`ModelSecurity::ClassMethods#query_permissions` in the context of the
record being returned.  This method is included in
:class:`ActiveRecord::Base`.

Implemetation details
---------------------

The filtering of records is done by including the access control tables in the
query using ``INNER JOIN`` s.  This means that the record is returned if and
only if:

- It has an :class:`Model::Node` associated record

- For each permission required:

  - In the node associated or in any ancestor (including the global node)
    there is at least one :class:`Model::Assignment` record for any of the
    principals of the user, associated with a :class:`Model::Role` record that
    has the required permission.

Since it is done through an ``INNER JOIN``, the query issued to the database
will contain all fields of the joined tables, plus the fields of the table on
wich :meth:`find` is run.  To return only the fields of the table, a custom
select is created instead of the default ``*``.  This is done as follows:

- If no ``:select`` option is provided when calling :meth:`find`, one is
  created using the table's name to return all its fields.  Then, the
  ``DISTINCT`` modifier is prepended to the select clause.

- If an option ``:select`` is passed to :meth:`find`, its value will be
  splitted in each comma, and for each of the references:

  - If the reference is a ``*``, it will be prefixed with the table's name.

  - If the reference represents a field of the table, it will be prefixed with
    the table's name.

  - If the reference is not a field of the table or is something more
    complex like a database function, then it is expected that the caller
    already provided the reference fully qualified, that is, each field
    referenced must have its table's name already prefixed.

  If the option ``select`` originally was not preceeded by ``DISTINCT``, the
  primary key of the table, which is usually ``id``, is included in the select
  (fully qualified), and ``DISTINCT`` is prepended to the clause.

In general, ``DISTINCT`` is always present in the final select clause.  This
is necessary because without that the query can return the same record
multiple times.  This happens, for example, if a required permission is found
in more than one assignment, or if the search requires more than one
permission.


Unrestricted :meth:`find`
=========================

This module introduces a method for unrestrictely search for records:
:meth:`ModelSecurity::ClassMethods#unrestricted_find`.


Hierarchy of records
====================

The hierarchy of nodes is a structure stored in the database used to keep
securable records linked between themselves.  It is maintained with the help
of some declarations done in each securable model class.  It is through this
hiearchy that permissions (to be more precise, roles) are inherited from
parent to child records.


Determining from where a model inherits permissions
---------------------------------------------------

To declare that a model class inherits permissions from some other models, one
must use the method
:meth:`ModelSecurity::ClassMethods#inherits_permissions_from`.  This methos
accepts names from associations, that will be queried each time the record is
created or saved.  Based on the values found in the association, the hierarchy
will be updated to reflect the inheritage of permissions.

This method can accept ``belongs_to``, ``has_many`` (without the ``:through``
option), ``has_one`` (without the ``:through`` options) and
``has_and_belongs_to_many`` associations.

If no parent association is defined all permissions will be inherited from the
global node.

.. warning::

   If a model inherits permissions from some association that is not a
   ``belongs_to``, that association must be declared as a propagation
   association in the model reflected.  See below how to do this.

   Without the propagation, the hierarchy of records **will** be broken.


Propagating permissions from a model to others
----------------------------------------------

In cases that a model inherits permissions from an association that is not a
belongs to, that is, the model doesn't hold the key to its parent, when the
parents of the model change (new parent added or a parent was removed) there
is the need to inform the model instances that they gained or lost a parent.
In such cases one can define which associations in the parent models are
subject to this change through defining *child associations*.  This is done by
calling :meth:`ModelSecurity::ClassMethods#propagates_permissions_to` in the
model class.  The defined associations will be queried and any object returned
will have its parents updated to include the record, at the time the record is
saved.

Unlike :meth:`ModelSecurity::ClassMethods#inherits_permissions_from`, only
``belongs_to`` and ``has_and_belongs_to_many`` associations can be used as
child associations.

The update happens by re-assigning the parents of each node found in the
children objects.  The parents of each node are obtained by calling their
:meth:`ModelSecurity::InstanceMethods#parents`, and therefore they can be
defined in their own classes through
:meth:`ModelSecurity::ClassMethods#inherits_permissions_from` or provided by
a custom implementation of :meth:`ModelSecurity::InstanceMethods#parents`.


Relationship between resources
------------------------------

Be comments belong to posts, and that access to a comment is allowed based on
permissions that the user has in the comment itself combined with permissions
in the post and the global node.  The definition of parent and child
associations would be::

  class Post < ActiveRecord::Base
    has_many :comments
  end

  class Comment < ActiveRecord::Base
    belongs_to :post
    inherits_permissions_from :post
  end

In the example above, no child association was set in the :class:`Post` class.
It is not necessary because :class:`Comment` holds the key to its parent
:class:`Post`.

Now another situation demonstrating a possible relationship between
:class:`Post` and :class:`Author`::

  class Post < ActiveRecord::Base
    has_and_belongs_to_many :authors
    inherits_permissions_from :authors
  end

  class Author < ActiveRecors::Base
    has_and_belongs_to_many :posts
    propagates_permissions_to :posts
  end

In the example above, posts can be authored by many authors and authors can
write many posts.  Also, authors propagate permissions to their posts, just
like posts inherit permissions from their authors --- users get permissions in
a post based on permissions they have in the post itself, the authors of the
post and the global node.  It is **required**, because of the
``has_and_belongs_to_many`` associations between posts and authors, to define
child associations in the :class:`Author` class.  Without the call to
:meth:`ModelSecurity::ClassMethods#propagates_permissions_to`, an author could
be updated and have a post removed from its ``posts`` association, but the
post removed would never know that it lost an author as parent in the access
control hierarchy.

Another example, using a ``has_many`` as parent::

  class Person < ActiveRecord::Base
    has_many :insurances
    inherits_permissions_from :insurances
  end

  class Insurance < ActiveRecord::Base
    belongs_to :person
    propagates_permissions_to :person
  end


In the example above, it is assumed two things:

- Who has access to an insurance will gain access to the insured person.
  
- In the normal workflow of the application a person gets created first, and
  then an insurance is created for that person.  This person can be in more
  than one insurance at a time (this is why it ``has_many :insurances``).

With this setup, when the insurance is created, due to the
``propagates_permissions_to`` declaration, the person instance will "know"
that it has just got a new parent from which permissions must be inherited.
Strictly speaking, the person instance will be instructed to check its parents
again, and update itself (hence the need to define the
``inherits_permissions_from`` in the :class:`Person` class).  This will happen
every time an insurance is created or updated its ``person_id`` foreign key.


Generating the hierarchy in a rake task
---------------------------------------

One can build an hierarchy using plain ruby, in a rake task, as follows::

  desc "build access control hieararchy"
  task :build_access_control_hieararchy => :environment do

    # Ensure that all models are already loaded.
    Dir[Rails.root + 'app/models/**/*.rb'].each{|path| require path}

    # For each model, get all records and for each record touch its node.
    ActiveRecord::Base.transaction do
      ObjectSpace.each_object(Class) do |klass|
        next if klass == ActiveRecord::Base
        next unless klass.ancestors.include?(ActiveRecord::Base)
        next unless klass.securable?
        # Call the ac_node to create it.
        klass.all.each(&:ac_node)
      end
    end

  end

This is a simplistic example.  It may have to be adjusted to specific needs.
But in general, each record from a model that has a table and is ``securable``
(see :meth:`ModelSecurity::ClassMethods#securable?`) should have a node (an
instance of :class:`Model::Node`).

:mod:`ModelSecurity` --- Methods used in model classes and instances
====================================================================

.. module:: ModelSecurity::ClassMethods
   :synopsis: This module provides basic declarative methods for setup security in models

.. moduleauthor:: Rafael Cabral Coutinho <rcabralc@tecnologiaenegocios.com.br>

Class methods available in the model's class level:

.. method:: protect(method_name, options)

   Set a permission requirement in a method named ``method_name``.
   ``options`` is a hash containing a key ``:with`` whose value can be either
   a single string representing a permission or an array or set of
   permissions.

   To get access to the method ``method_name`` the user must have all
   permissions listed in the ``options[:with]`` parameter.

.. method:: inherits_permissions_from(*args)

   State that the each argument, representing the name of a ``has_many``,
   ``has_one`` or ``belongs_to`` association, is a parent association, that
   is, permissions can be inherited from them.  Each argument can be either a
   symbol or a string.
   
   If no argument is passed the current parent association names are returned.

   If some argument represents an inexistent association, or a ``has_many
   :through`` or ``has_one :through`` a ``has_and_belongs_to_many``
   association, :class:`AccessControl::InvalidInheritage` is raised.

.. method:: propagates_permissions_to(*args)

   State that each argument, representing the name of a ``belongs_to``
   association, is a child association of the records of the class, that is,
   each record from these associations inherits permissions from this record.
   Each argument can be a symbol or a string.

   If no argument is passed the current child association names are returned.

   If some argument represents an inexistent association, or a
   non-``belongs_to`` association,
   :class:`AccessControl::InvalidPropagation` is raised.

.. method:: query_permissions=(permissions)

   Set a default set of permissions to use to restrict query results (namely
   when using :meth:`find` or similars).

   ``permissions`` can be either a single string or an array or set of strings,
   each string being the name of a permission.

   Setting query permissions using this method will override the default query
   permissions used system-widely just for the class where it is being
   defined.

.. method:: query_permissions

   Return the current query permissions used by the class.  If no permissions
   wher set through :meth:`query_permissions=`, the default permissions from
   system configuration are returned, along with additional permissions
   defined through :meth:`additional_query_permissions=`.  In any case, the
   value returned is an array.

   If :meth:`query_permissions=` was used to set permissions, the default
   permissions from the system configuration and any additional permissions
   are ignored, and the value set is returned.

   .. warning::

      Modifying the array returned from this method **when there were no
      permissions set previously** through :meth:`query_permissions=`, like
      :meth:`<<`'ing to it or :meth:`concat`'ing it, will modify the
      system-wide default value.  It's ok to do it if some permissions where
      set previously, though.

.. method:: additional_query_permissions=(permissions)

   Set additional query permissions to use to restrict query results (namely
   when using :meth:`find` or similars).

   The behaviour of this method is similar to :meth:`query_permissions=`,
   except that it do not override system-wide query permissions for this
   class.  Using it will make queries to be restricted with the default query
   permissions in addition to those defined with this method.

.. method:: additional_query_permissions

   Return the current additional query permissions for the class or an empty
   array if none was set through :meth:`additional_query_permissions=`.

   .. note::

      Modifying the array returned is ok in any situation.

.. method:: unrestricted_find(*args)

   Return records in the same way of :meth:`ActiveRecord::Base#find`.

.. method:: find(*args)

   Perform the query restriction.

.. method:: securable?

   Return ``true`` by default for every model class.  If ``true``, the class
   is subjected to access control.  Every method call on its instances will be
   checked using the permission defined through :meth:`protect`, queries
   will be restricted and a node is created when a record is created.
   
   Overriding it to return ``false`` will disable :class:`Model::Node`
   creation and disable checks in method calls and queries.

.. module:: ModelSecurity::InstanceMethods
   :synopsis: Methods added to ActiveRecord::Base that can be called on instances

.. moduleauthor:: Rafael Cabral Coutinho <rcabralc@tecnologiaenegocios.com.br>

The following methods are provided as instance methods:

.. method:: parents

   Return all parent objects of this record.  Records are fetched from the
   parent associations, defined through the class method
   :meth:`inherits_permissions_from`.

.. method:: children

   Return all child objects of this record.  Records are fetched from the
   child associations, defined through the class method
   :meth:`propagates_permissions_to`.
