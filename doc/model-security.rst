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
query using `INNER JOIN` s.  This means that the record is returned if and
only if:

- It has an :class:`Model::Node` associated record

- For each permission required:

  - In the node associated or in any ancestor (including the global node)
    there is at least one :class:`Model::Assignment` record for any of the
    principals of the user, associated with a :class:`Model::Role` record that
    has the required permission.

Since it is done through an `INNER JOIN`, the query issued to the database
will contain all fields of the joined tables, plus the fields of the table on
wich :meth:`find` is run.  To return only the fields of the table, a custom
select is created instead of the default `*`.  This is done as follows:

- If no `:select` option is provided when calling :meth:`find`, one is created
  using the table's name to return all its fields.

- If an option `:select` is passed to :meth:`find`, this select must comply
  with the following:

  - It must be a single `*`, OR

    - The `*` is then prefixed with the table's name automatically

  - It must be a comma-separated list of references

    - If the reference represents a field of the table, it will be prefixed
      with the table's name automatically.

    - If the reference is not a field of the table or is something more
      complex like a function, then it is expected that the caller already
      provided the reference fully qualified, that is, each field referenced
      must have its table's name already prefixed.


Unrestricted :meth:`find`
=========================

This module introduces a method for unrestrictely search for records:
:meth:`ModelSecurity::ClassMethods#unrestricted_find`.


Hierarchy of records
====================

The hierarchy of nodes is maintained with the help of some defined behaviour
that the application code must declare on each model class.

Defining an association to be the *parent association*
------------------------------------------------------

A parent association is defined by using the class method
:meth:`ModelSecurity::ClassMethods#parent_association`.

The association defined as parent will be queried when a record is created or
its node is accessed by the first time.  The node of each object returned by
the association (which can be only one record for ``has_one`` or
``belongs_to`` or many records for ``has_many`` or
``has_and_belongs_to_many``) is a parent node of the record.  The hierarchy is
updated accordingly.

At most one parent association is supported per model class.  If no parent
association is defined, the record will have its node right below the global
node.

If a simple association is not enough to express the parents of a model
instance, one must override the method
:meth:`ModelSecurity::InstanceMethods#parents` to return an arbitrary array of
objects that will be the parents of the record.


Updating parents in another records from a given record
-------------------------------------------------------

In some cases there is the need to inform another instances that they gained a
new parent.  In such cases one can define which associations are subject to
this change through defining *child associations*.  This is done by
calling :meth:`ModelSecurity::ClassMethods#child_associations` in the model
class.  The defined associations will be queried and any object returned will
have its parents updated to include the record, at the time the record is
saved.

Unlike :meth:`ModelSecurity::ClassMethods#parent_association`, one can create
many child associations.  If no child association is defined, no update is
performed.

The update happens by re-assigning the parents of each node found in the
children objects.  The parents of each node are obtained by calling their
:meth:`ModelSecurity::InstanceMethods#parents`, and therefore they can be
defined in their own classes through
:meth:`ModelSecurity::ClassMethods#parent_association` or provided by custom
implementation of :meth:`ModelSecurity::InstanceMethods#parents`.

If defining children association is not enough to cover specific needs, one
can override the method :meth:`ModelSecurity::InstanceMethods#children` of the
model instance.

.. warning::

   The mis-use of parent and child associations can lead to infinite
   recursion.  It must be assured by the application code that there's no
   cycle in the hierarchy created by mis-using these methods.


Generating the hierarchy in a rake task
---------------------------------------

One can build an hierarchy using plain ruby, in a rake task, as follows::

  desc "build access control hieararchy"
  task :build_access_control_hieararchy => :environment do

    # Ensure that all models are already loaded.
    Dir[ENV['RAILS_ROOT'] + '/app/models/**/*.rb'].each{|path| require path}

    # For each model, get all records and for each record touch its node.
    ObjectSpace.each_object(Class) do |klass|
      next if klass == ActiveRecord::Base
      next unless klass.ancestors.include?(ActiveRecord::Base)
      next unless klass.securable?
      # Call the ac_node to create it.
      klass.all.each{|r| r.ac_node}
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

   Set a permission requirement in a method named *method_name*.  *options* is
   a hash containing a key *:with* whose value can be either a single string
   representing a permission or an array or set of permissions.

   To get access to the method *method_name* the user must have all
   permissions listed in the *options[:with]* parameter.

.. method:: parent_association(association_name=nil)

   State that the association named *association_name* is the parent
   association.  *association_name* can be either a symbol or a string.  This
   is a convenient way to build an hierarchy of records.  The :meth:`parents`
   instance method by default will look at the defined parent association and
   automatically provide one or more parents, based on the record(s) in the
   association.

   If *association_name* is nil (or omitted), the current parent association
   name is returned instead.

   Overriding :meth:`parents` directly can be done instead when simply stating
   an association as a parent or parents objects is not enough.

.. method:: child_associations(*args)

   State that each argument, representing the name of an association, is a
   child association of the records of the class.  Each argument can be a
   symbol or a string.  This is a convenient way to create new parents for
   existing records.

   If no argument is passed, the current child associations are returned.

   Overriding :meth:`children` directly can be done instead when simply
   stating associations as children objects is not enough.

.. method:: query_permissions=(permissions)

   Set a default set of permissions to use to restrict query results (namely
   when using :meth:`find` or similars).

   *permissions* can be either a single string or an array or set of strings,
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

   Return all parent objects of this record.  Records are fetched by default
   from the parent association, defined in the class method
   :meth:`parent_association`.

   Overriding this method provides a way to subclasses to get more control on
   how the access control hierarchy is built.

.. method:: children

   Return all children objects of this record.  Records are fetched by default
   from the child associations, defined in the class method
   :meth:`child_associations`.

   Overriding this method provides a way to subclasses to get more control on
   how the access control hierarchy is built.
