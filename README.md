# Opie

[![Build Status](https://travis-ci.org/guzart/opie.svg?branch=master)](https://travis-ci.org/guzart/opie)
[![codecov](https://codecov.io/gh/guzart/opie/branch/master/graph/badge.svg)](https://codecov.io/gh/guzart/opie)
[![Code Climate](https://codeclimate.com/github/guzart/opie/badges/gpa.svg)](https://codeclimate.com/github/guzart/opie)
[![Gem Version](https://badge.fury.io/rb/opie.svg)](https://badge.fury.io/rb/opie)


TODO: describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'opie'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install opie

## Usage

_Tentative API_

The `Opie::Operation` API:
  * `::step(method_name: Symbol) -> void` indicates a method that is executed in the operation sequence
  * `::failure(method_name: Symbol) -> void` indicates the method that handles failures
  * `#success? -> Boolean` indicates  whether the operation was successful
  * `#output -> *` if succcessful, it returns the operation final output
  * `#fail(error_type: Symbol, error: Error) -> OpieFailure` 
  * `#failure? -> Boolean` indicates  whether the operation was a failure
  * `#error_type -> Symbol` return the failure error type 
  * `#errors -> Array<JSONAPIError>` returns the operation JSONAPI compatible errors
  * `#internal_error -> void` sets the operation error_type and errors to indicate an internal error
  * `#not_found_error -> void` sets the operation error_type and errors to indicate a resource not found error
  * `#validation_error(errors: Hash) -> void` sets the operation error_type and errors to indicate a 
  validation error

## Example

Imagine yourself in the context of a [habit tracker](https://github.com/isoron/uhabits).

```ruby
# Let's add a habit we want to track
class HabitsController < ApplicationController
  def create
    # run the `operation` – since it's a modification we can call it a `command`
    result = Humans::AddHabit.(habit_params, dependencies) # optionally, we can specify dependencies

    # render response based on operation result
    if result.success?
      render status: :created, json: result.output
    else
      render status: http_status(result.error_type), json: { errors: result.errors }
    end
  end

  private

  # the HTTP status depends on the error type, which separating the domain from the infrastructure
  def http_status(error_type)
    case(error_type) 
    when :validation then :unprocessable_entity 
    when :not_found then :not_found
    else :server_error
    end
  end

  # simulate parameters came from a Http request
  def habit_params
    {
      human_id: 2,
      name: 'Excercise',
      description: 'Did you excercise for at least 15 minutes today?',
      frequency: :three_times_per_week,
      color: 'DeepPink'
    }
  end

  # simulate we have some application-wide dependencies
  def dependencies
    {
      'repositories.habit': HabitRepository.new,
      'repositories.human': HumanRepository.new,
      'service_bus': ServiceBus.new
    }
  end
end

module Humans
  # we define a validation schema for our input
  Schema = Dry::Schema.Validation do
    configure do
      # custom predicate for frequency
      def freq?(value)
        [:weekly, :five_times_per_week, :four_times_per_week, :three_times_per_week].includes?(value)
      end
    end
    
    required(:human_id).filled(:int?, gt?: 0)
    required(:name).filled(:str?)
    required(:description).maybe(:str?)
    required(:frequency).filled(:freq?)
    required(:color).filled(:str?)
  end

  # the operation logic starts
  class AddHabit < Opie::Operation
    # project's dependency injection, more flexible than ruby's global namespace
    include HabitTrackerDependencies 

    # first step receives ::new first argument, then the output of the step is the argument of the next step
    step :validate
    step :find_human
    step :persist_habit
    step :send_event
    failure :handle_failure # define the method that handles the sad path

    # receives the first input
    def validate(params)
      schema = Schema.(params)
      return fail(:validation, schema.errors) if schema.failure?
      schema.output
    end

    # if it's valid then find the human (tenant)
    def find_human(params)
      human = resolve('repositories.human').find(params[:human_id])
      return fail(:repository, StandardError.new('We could not find your account')) unless human
      params.merge(human: human)
    end

    # persist the new habit
    def persist_habit(params)
      new_habit = Entities::Habit.new(params)
      resolve('repositories.habit').create(new_habit)
    rescue => error
      fail(:persist_failed, error)
    end

    # notify the world
    def send_event(habit)
      event = Habits::CreatedEvent.new(habit.attributes)
      resolve('service_bus').send(event)
    rescue => error
      fail(:event_failed, error)
    end

    # oopsy daisies handling
    def handle_failure(type, error)
      case (type)
        # opie method for handling Dry::Struct.Validation errors
        when :validation then validation_errors(error)
        # yes, another opie method for handling resource finding errors
        when :not_found then not_found_error
        # yet, another opie method for internal errors
        else internal_error
      end
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/guzart/opie.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

