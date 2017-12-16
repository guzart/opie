# Opie

[![Build Status](https://travis-ci.org/guzart/opie.svg?branch=master)](https://travis-ci.org/guzart/opie)
[![codecov](https://codecov.io/gh/guzart/opie/branch/master/graph/badge.svg)](https://codecov.io/gh/guzart/opie)
[![Code Climate](https://codeclimate.com/github/guzart/opie/badges/gpa.svg)](https://codeclimate.com/github/guzart/opie)
[![Gem Version](https://badge.fury.io/rb/opie.svg)](https://badge.fury.io/rb/opie)

**Opie gives you a simple API for creating Operations using the
[Railsway oriented programming](https://vimeo.com/113707214) paradigm.**

## API

The `Opie::Operation` API:
  * `::step(Symbol) -> void` indicates a method that is executed in the operation sequence
  * `#success? -> Boolean` indicates  whether the operation was successful
  * `#failure? -> Boolean` indicates  whether the operation was a failure
  * `#failure -> Opie::Failure | nil` the failure if the operation is a `failure?`, nil when it's a success
  * `#failures -> Array<Opie::Failure> | nil` an array with all failures
  * `#output -> * | nil` the operation's last step return value, nil when the operation fails

Internal API:
  * `#step_name(Any, Any?) -> Any` the step signature. First argument is the input and the second argument is an optional context
  * `#fail(error_type: Symbol, error_data: *) -> Opie::Failure` used inside the steps to indicate that the operation has failed

Executing an operation:

```ruby
input = { first_name: 'John', last_name: 'McClane', email: 'john@example.com' }
context = { current_user: 'admin' }

CreateUserOperation.(input, context)
```

_Tentative API_

  * `::step(Array<Symbol>) -> void` a series of methods to be called in parallel
  * `::step(Opie::Step) -> void` an enforcer of a step signature which helps to compose other steps
  * `::failure(Symbol) -> void` indicates a custom method name to handle failures

## Usage

**Simple Usage:**

```ruby
# Create an Operation for completing a Todo
class Todos::CompleteTodo < Opie::Operation
  step :find_todo
  step :mark_as_complete

  def find_todo(todo_id)
    todo = Todo.find_by(id: todo_id)
    return fail(:not_found, "Could not find the Todo using id: #{todo_id}") unless todo
    todo
  end

  def mark_as_complete(todo)
    success = todo.update(completed_at: Time.zone.now)
    return fail(:update) unless success
    todo
  end
end

class TodosController < ApplicationController
  def complete
    # invoke the operation
    result = Todos::CompleteTodo.(params[:id])
    if result.success? # if #success?
      render status: :created, json: result.output # use output
    else
      render status: :bad_request, json: { error: error_message(result.failure) } # otherwise use #failure
    end
  end

  private

  def error_message(failure)
    case failure.type
      when :not_found then failure.data
      when :update then 'We were unable to make the changes to your todo'
      else 'There was an unexpected error, sorry for the inconvenience'
    end
  end
end
```

**Real world example:**

Imagine yourself in the context of a [habit tracker](https://github.com/isoron/uhabits), wanting to 
add a new habit to track.

```ruby
# app/controllers/habits_controller.rb

class HabitsController < ApplicationController
  # POST /habits
  def create
    # run the `operation` – since it's a modification we can call it a `command`
    result = People::AddHabit.(habit_params, operation_context)

    # render response based on operation result
    if result.success?
      render status: :created, json: result.output
    else
      render_operation_failure(result.failure)
    end
  end

  private

  def render_operation_failure(failure)
    render status: failure_http_status(failure.type), json: { errors: failure.data }
  end

  # the HTTP status depends on the error type, which separating the domain from the infrastructure
  def failure_http_status(type)
    case(type)
    when :unauthorized then :unauthorized
    when :validation then :unprocessable_entity 
    when :not_found then :not_found
    else :server_error
    end
  end

  # simulate parameters came from a Http request
  def habit_params
    {
      person_id: 2,
      name: 'Excercise',
      description: 'Did you excercise for at least 15 minutes today?',
      frequency: :three_times_per_week,
      color: 'DeepPink'
    }
  end

  def operation_context
    { current_user: current_user }
  end
end
```

And now the code that defines the operation

```ruby
# application-wide dependencies container
class HabitTrackerContainer
  extends Dry::Container::Mixin

  register 'repositories.habit', HabitRepository.new
  register 'repositories.person', PersonRepository.new
  register 'service_bus', ServiceBus.new
end

# application-wide dependency injector
Import = Dry::AutoInject(HabitTrackerContainer.new)

module People
  # we define a validation schema for our input
  AddHabitSchema = Dry::Schema.Validation do
    configure do
      # custom predicate for frequency
      def freq?(value)
        [:weekly, :five_times_per_week, :four_times_per_week, :three_times_per_week].includes?(value)
      end
    end
    
    required(:person_id).filled(:int?, gt?: 0)
    required(:name).filled(:str?)
    required(:description).maybe(:str?)
    required(:frequency).filled(:freq?)
    required(:color).filled(:str?)
  end

  # the operation logic starts
  class AddHabit < Opie::Operation 
    # inject dependencies, more flexible than ruby's global namespace
    include Import[
      habit_repo: 'repositories.habit',
      person_repo: 'repositories.person',
      service_bus: 'service_bus'
    ]

    # first step receives ::call first argument, then the output of the step is the argument of the next step
    step :authorize
    step :validate
    step :find_person
    step :persist_habit
    step :send_event

    def authorize(params, context)
      # Authorize using Pundit's policy api
      return fail(:unauthorized) if HabitPolicy.new(context, Habit).add?
      params
    end

    # receives the first input
    def validate(params)
      schema = AddHabitSchema.(params)
      return fail(:validation, schema.errors) if schema.failure?
      schema.output
    end

    # if it's valid then find the person (tenant)
    def find_person(params)
      person = person_repo.find(params[:person_id])
      return fail(:repository, 'We could not find your account') unless person
      params.merge(person: person)
    end

    # persist the new habit
    def persist_habit(params)
      new_habit = Entities::Habit.new(params)
      habit_repo.create(new_habit)
    rescue => error
      fail(:persist_failed, error.message)
    end

    # notify the world
    def send_event(habit)
      event = Habits::CreatedEvent.new(habit.attributes)
      service_bus.send(event)
    rescue => error
      fail(:event_failed, error)
    end
  end
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'opie'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install opie
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update
the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for
the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/guzart/opie.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

