====================
AccessControl Models
====================

.. default-domain:: rb
.. highlight:: ruby

:class:`Node` --- A node in the access control tree
===================================================

Every record in the application where this gem is installed, unless specified
otherwise, will have a node in the access control tree.  Nodes are represented
by the model class :class:`Node`.

To access the node of any record call the `ac_node` association.  This should
return a :class:`Node` instance.

To prevent that records from a specific model have corresponding nodes in the
access control tree, define the following class method in the model::

  class MyUnsecurableModel < ActiveRecord::Base
    def self.securable?
      false
    end
  end

.. note::

   This should be done for models that have no user inteface, like supporting
   data.  It is not recommended to do so for stuff that users will handle,
   because such data should be subject to the access control.

.. class:: Node

   .. method:: global?

      Return true if the node is the global node, false otherwise.

   .. method:: has_permission?(permission)

      Given a permission (a :class:`String`), return true if the current user
      has it in the context of the node, false otherwise.

      It will consider any inherited role as long the inheritance is not
      blocked.

   .. method:: permissions

      Return all permission names in the context of the node for the current
      user.
      
      Like :meth:`has_permission?` this will consider all inherited roles as
      long the inheritance is not blocked.  The value returned is a
      :class:`Set`.

   .. method:: assignments

      Return the associated assignments, which are records of the
      :class:`Assignment` model.

      This is a regular `has_many` association method, and all variants,
      including a writer method, are available.

   .. method:: principal_assignments

      Return the associated assignments for the current user only (that is,
      the current user is included in the conditions of the association,
      dinamically).

      This is a regular `has_many` association method, and all variants should
      be available.  The only exception is probably the writer method, which
      exists but the results of using it are undefined.

   .. method:: principal_roles

      Return the associated roles for the current user.

      This is a regular `has_many` `:though` association which uses the
      :meth:`principal_assignments` association.

   .. method:: self.global

      Return the global node.

      This method caches the global node in a class instance variable, to
      speed up further calls.
