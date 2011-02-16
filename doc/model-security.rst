==============
Model Security
==============

.. default-domain:: rb

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

The association defined as parent will be queried when a record is created or
its node is accessed by the first time.  The node of each object returned by
the association (which can be only one record for ``has_one`` or
``belongs_to`` or many records for ``has_many`` or
``has_and_belongs_to_many``) is a parent node of the record.  The hierarchy is
updated accordingly.

At most one parent association is supported per model class.  If no parent
association is defined, the record will have its node right below the global
node.

A parent association is defined by using the class method
:meth:`ModelSecurity::ClassMethods#parent_association`.


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

.. module:: ModelSecurity::InstanceMethods
   :synopsis: Methods added to ActiveRecord::Base that can be called on instances

.. moduleauthor:: Rafael Cabral Coutinho <rcabralc@tecnologiaenegocios.com.br>

The following method is provided as in instance method:

.. method:: parents

   Return all parent objects of this record.  Records are fetched from the
   parent association, defined in the class method :meth:`parent_association`.

   Overriding this method provides a way to subclasses to get more control on
   how the access control hierarchy is built.
