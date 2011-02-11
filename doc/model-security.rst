:mod:`ModelSecurity` --- Methods used in model classes and instances
====================================================================

.. default-domain:: rb

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


.. module:: ModelSecurity::InstanceMethods
   :synopsis: Methods added to ActiveRecord::Base that can be called on instances

.. moduleauthor:: Rafael Cabral Coutinho <rcabralc@tecnologiaenegocios.com.br>

The folloing method is provided as in instance method:

.. method:: parents

   Return all parent objects of this record.  Records are fetched from the
   parent association, defined in the class method :meth:`parent_association`.

   Overriding this method provides a way to subclasses to get more control on
   how the access control hierarchy is built.
