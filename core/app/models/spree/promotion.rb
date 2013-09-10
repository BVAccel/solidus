module Spree
  class Promotion < ActiveRecord::Base
    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    has_many :promotion_rules, foreign_key: :activator_id, autosave: true, dependent: :destroy
    alias_method :rules, :promotion_rules

    has_many :promotion_actions, foreign_key: :activator_id, autosave: true, dependent: :destroy
    alias_method :actions, :promotion_actions

    accepts_nested_attributes_for :promotion_actions, :promotion_rules

    validates_associated :rules

    validates :name, presence: true
    validates :path, presence: true, if: lambda{|r| r.event_name == 'spree.content.visited' }
    validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }

    # TODO: This shouldn't be necessary with :autosave option but nested attribute updating of actions is broken without it
    after_save :save_rules_and_actions

    def save_rules_and_actions
      (rules + actions).each &:save
    end

    def self.advertised
      where(advertise: true)
    end

    def self.active
      where('starts_at IS NULL OR starts_at < ?', Time.now).
        where('expires_at IS NULL OR expires_at > ?', Time.now)
    end

    def expired?
      starts_at && Time.now < starts_at || expires_at && Time.now > expires_at
    end

    def activate(payload)
      return unless order_activatable? payload[:order]

      if path.present?
        return unless path == payload[:path]
      end

      # Track results from actions to see if any action has been taken.
      # Actions should return nil/false if no action has been taken.
      # If an action returns true, then an action has been taken.
      results = actions.map do |action|
        action.perform(payload)
      end
      # If an action has been taken, report back to whatever activated this promotion.
      return results.include?(true)
    end

    # called anytime order.update! happens
    def eligible?(order)
      return false if expired? || usage_limit_exceeded?(order)
      rules_are_eligible?(order, {})
    end

    def rules_are_eligible?(order, options = {})
      return true if rules.none?
      eligible = lambda { |r| r.eligible?(order, options) }
      if match_policy == 'all'
        rules.all?(&eligible)
      else
        rules.any?(&eligible)
      end
    end

    def order_activatable?(order)
      order && !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    # Products assigned to all product rules
    def products
      @products ||= self.rules.to_a.inject([]) do |products, rule|
        rule.respond_to?(:products) ? products << rule.products : products
      end.flatten.uniq
    end

    def product_ids
      products.map(&:id)
    end

    def usage_limit_exceeded?(order = nil)
      usage_limit.present? && usage_limit > 0 && adjusted_credits_count(order) >= usage_limit
    end

    def adjusted_credits_count(order)
      return credits_count if order.nil?
      credits_count - (order.promotion_credit_exists?(self) ? 1 : 0)
    end

    def credits
      Adjustment.promotion.where(source_id: actions.map(&:id))
    end

    def credits_count
      credits.count
    end
  end
end
