# Opie

[![Build Status](https://travis-ci.org/guzart/opie.svg?branch=master)](https://travis-ci.org/guzart/opie)
[![codecov](https://codecov.io/gh/guzart/opie/branch/master/graph/badge.svg)](https://codecov.io/gh/guzart/opie)
[![Code Climate](https://codeclimate.com/github/guzart/opie/badges/gpa.svg)](https://codeclimate.com/github/guzart/opie)
[![Gem Version](https://badge.fury.io/rb/opie.svg)](https://badge.fury.io/rb/opie)

**Opie gives you a simple API for creating Operations using the
[Railsway oriented programming](https://vimeo.com/113707214) paradigm.**

## Usage

**Simple Usage:**

```ruby
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
    result = Todos::CompleteTodo.(params[:id])
    if result.success?
      render status: :created, json: result.output
    else
      render status: :bad_request, json: { error: error_message(result) }
    end
  end

  private

  def error_message(failure)
    case failure[:type]
      when :not_found then failure[:data]
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
    result = People::AddHabit.(habit_params)

    # render response based on operation result
    if result.success?
      render status: :created, json: result.output
    else
      render status: error_http_status(result.failure[:type]), json: { errors: [result.failure] }
    end
  end

  private

  # the HTTP status depends on the error type, which separating the domain from the infrastructure
  def error_http_status(error_type)
    case(error_type) 
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
end
```

And now the code that defines the operation

```ruby
# application-wide dependencies
class HabitTrackerContainer
  extends Dry::Container::Mixin

  register 'repositories.habit', HabitRepository.new
  register 'repositories.person', PersonRepository.new
  register 'service_bus', ServiceBus.new
end

# base class for all project operations
class ApplicationOperation < Opie::Operation
  # default container to used for dependency injection, more flexible than ruby's global namespace
  dependencies -> { HabitTrackerContainer }
end

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

  # the operation logic starts, by inheriting from ApplicationOperation we get default dependencies
  class AddHabit < ApplicationOperation
    # first step receives ::new first argument, then the output of the step is the argument of the next step
    step :validate
    step :find_person
    step :persist_habit
    step :send_event

    # receives the first input
    def validate(params)
      schema = AddHabitSchema.(params)
      return fail(:validation, schema.errors) if schema.failure?
      schema.output
    end

    # if it's valid then find the person (tenant)
    def find_person(params)
      person = resolve('repositories.person').find(params[:person_id])
      return fail(:repository, 'We could not find your account') unless person
      params.merge(person: person)
    end

    # persist the new habit
    def persist_habit(params)
      new_habit = Entities::Habit.new(params)
      resolve('repositories.habit').create(new_habit)
    rescue => error
      fail(:persist_failed, error.message)
    end

    # notify the world
    def send_event(habit)
      event = Habits::CreatedEvent.new(habit.attributes)
      resolve('service_bus').send(event)
    rescue => error
      fail(:event_failed, error)
    end
  end
end
```

## API

The `Opie::Operation` API:
  * `::step(method_name: Symbol) -> void` indicates a method that is executed in the operation sequence
  * `#success? -> Boolean` indicates  whether the operation was successful
  * `#failure? -> Boolean` indicates  whether the operation was a failure
  * `#error -> Hash` the erorr if the operation is a `failure?`
  * `#output -> *` if succcessful, it returns the operation final output
  validation error

Internal API:
  * `#fail(error_type: Symbol, error_data: *) -> Hash` 

_Tentative API_

  * `::failure(method_name: Symbol) -> void` indicates the method that handles failures
  * `::dependencies(Lambda) -> void` sets the default structure used to resolve dependencies
  * `#resolve(key: String) -> *` returns the dependency registered with the given key
  * `#errors -> Array<Opie::Error>` returns the operation JSONAPI compatible errors
  * `#internal_error -> void` sets the operation error_type and errors to indicate an internal error
  * `#not_found_error -> void` sets the operation error_type and errors to indicate a resource not found error
  * `#validation_error(errors: Hash) -> void` sets the operation error_type and errors to indicate a 

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

