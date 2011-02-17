================
Security Manager
================

.. highlight:: rb

The security manager is an object that manages all security in the system.  It
knows about the current user and its groups (with a little help of the
controller).  It can be used to control whether or not the queries in the
system will be restricted or to verify if the current user has one or more
given permissions in a specific record (its node, actually).

It can be obtained in the following way::

  manager = AccessControl.get_security_manager

The security manager object is stored in a thread variable (for thread
safety).  It is usually set through the *around_filter*
:meth:`ControllerSecurity::InstanceMethods#run_with_security_manager`.  So,
once this filter is run the manager can be obtained through
:meth:`AccessControl#get_security_manager`.

One can disable the security manager (once it was set --- otherwise it may not
work) by calling :meth:`AccessControl#no_security_manager`.

:class:`SecurityManager`
========================

.. class:: SecurityManager

   .. method:: initialize(controller)
  
     The initialization method of the security manager.  Takes the current
     controller instance as the only parameter.
  
   .. method:: principal_ids
  
     Return the ids of all principals belonging to the current user.
  
     .. note::
  
       The current user is obtained by calling :meth:`current_user` in the
       controller instance.  Therefore, it must be implemented by the
       application code.  The groups of the user are obtained by calling
       :meth:`current_groups` in the controller instance, and also must be
       supplied by application code.
  
   .. method:: has_access?(node, permissions)
  
     Return ``true`` if the current user has *all* permissions ``permissions``
     in the given node ``node`` (or above it), ``false`` otherwise.
  
  
   .. method:: verify_access!(node, permissions)
  
     Raise :class:`AccessControl::Unauthorized` if the user is missing one or
     more permissions from ``permissions`` in the node ``node`` (or above it).
  
   .. method:: restrict_queries?
  
     Return ``true`` if query restriction is enabled system-wide, ``false``
     otherwise.
  
   .. method:: restrict_queries=
  
   .. method:: restrict_queries
  
     Accessors for query restriction.
