===================
Controller Security
===================

:mod:`ControllerSecurity` --- Methods used in ApplicationController
===================================================================

.. default-domain:: rb
.. highlight:: ruby

.. module:: ControllerSecurity::ClassMethods
   :synopsis: Provides a basic declarative method to setup security for
              actions in a controller

.. moduleauthor:: Rafael Cabral Coutinho <rcabralc@tecnologiaenegocios.com.br>

This module provides class methods and instance methods for
:class:`ApplicationController` and its derivatives.

.. method:: protect(action_name, options)

   Protect the action named by *action_name* with one or more permissions
   given in the *options* hash under the key *:with*.

   *action_name* can be either a string or a symbol.

   *options[:with]* can be either a single string or an array or set of
   strings, each one representing a permission.

   The access to the action *action_name* will be given to the current user
   only if it has all permissions in *options[:with]* in the context given by
   the instance method :meth:`current_security_context`.

   This method expects that :meth:`run_with_security_manager` be set as a
   global *around_filter*.

   Example::

      class PeopleController < ApplicationController
        ...
        protect :edit, :with => 'edit'
        ...
        def edit
          ..
        end
        ...
      end

.. module:: ControllerSecurity::InstanceMethods
   :synopsis: Basic around filter and security context in a controller

.. moduleauthor:: Rafael Cabral Coutinho <rcabralc@tecnologiaenegocios.com.br>

.. method:: run_with_security_manager

   This method is meant to be used as an *around_filter*.  The filter must be
   set before any :meth:`protect` call, in the :class:`ApplicationController`
   class.

   Example::

      class ApplicationController < ActionController::Base
        ...
        around_filter :run_with_security_manager
        ...
        protect ...
        ...
      end

   Every controller must have :meth:`current_user` and :meth:`current_groups`
   methods defined, or inherit from :class:`ApplicationController`, as this is
   expected by this filter.

   Since this method is meant to be used as a filter it is declared private.

.. method:: current_user
.. method:: current_groups

   These methods must be defined in the controller to allow the system to know
   the current user and its groups.

   You probably want to define a *before_filter* at the top of your
   :class:`ApplicationController` class that performs authentication and sets
   the current user in an instance var::

      class ApplicationController < ActionController::Base

        before_filter :authenticate
        around_filter :run_with_security_manager
        ..

        private

          def authenticate
            # Perform the logic of authentication...
            @current_user = the_user_that_we_found
          end

          def current_user
            @current_user
          end

          def current_groups
            @current_user.groups
          end

      end

   Note that the the :meth:`run_with_security_manager` around filter is
   declared after the *before_filter* for authentication.  This is done to
   ensure that when the *around_filter* is run the authentication alread has
   been done (and a current user may already have been assigned).

   .. note::

      ``current_user`` and ``current_groups`` can be declared protected or
      public too, but it is generally a good idea to keep them private.  Also,
      it is a good idea to keep filters private too, as we did in the example
      with ``authenticate``.

   .. note::

      You may not have the concept of user groups in your application.  If so,
      you don't need to implement ``current_groups`` (the default
      implementation will simply return an empty array, which is what you need
      in such case).

   .. note::

      The user can fail to authenticate, perhaps because it is anonymous or
      its cookie is invalid or it mistyped the password, or any other reason.
      If an user could not be authenticated, returning ``nil`` from
      :meth:`current_user` is the right way to tell the system that there's no
      current user defined, and the requests should be treated as being done
      by an anonymous user.
