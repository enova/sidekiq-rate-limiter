unless ENV['COVERAGE'] == 'false'
  require 'simplecov-rcov'

  class SimpleCov::Formatter::MergedFormatter
    def format(result)
      SimpleCov::Formatter::HTMLFormatter.new.format(result)
      SimpleCov::Formatter::RcovFormatter.new.format(result)
    end
  end

  SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter
end
