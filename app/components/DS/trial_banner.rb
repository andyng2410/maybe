class DS::TrialBanner < DesignSystemComponent
  def initialize(family:)
    @family = family
  end

  def render?
    @family.present? && @family.trialing? && @family.days_left_in_trial.present?
  end

  private
    attr_reader :family

    def days_left
      family.days_left_in_trial
    end

    def percentage_completed
      family.percentage_of_trial_completed
    end

    def urgency_variant
      return :error if days_left <= 1
      return :warning if days_left <= 3
      :info
    end

    def container_classes
      base_classes = "flex items-center justify-between gap-4 p-4 border-b"

      variant_classes = case urgency_variant
      when :error
        "bg-red-50 text-red-800 border-red-200 theme-dark:bg-red-900/20 theme-dark:text-red-300 theme-dark:border-red-800"
      when :warning
        "bg-yellow-50 text-yellow-800 border-yellow-200 theme-dark:bg-yellow-900/20 theme-dark:text-yellow-300 theme-dark:border-yellow-800"
      else
        "bg-blue-50 text-blue-800 border-blue-200 theme-dark:bg-blue-900/20 theme-dark:text-blue-300 theme-dark:border-blue-800"
      end

      "#{base_classes} #{variant_classes}"
    end

    def icon_name
      case urgency_variant
      when :error
        "alert-circle"
      when :warning
        "clock"
      else
        "info"
      end
    end

    def message
      if days_left == 0
        "Your trial expires today!"
      elsif days_left == 1
        "Your trial expires tomorrow!"
      else
        "#{days_left} days left in your trial"
      end
    end
end
