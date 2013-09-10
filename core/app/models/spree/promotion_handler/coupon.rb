module Spree
  module PromotionHandler
    class Coupon
      attr_reader :order
      attr_accessor :error, :success

      def initialize(order)
        @order = order
      end

      def apply
        if order.coupon_code.present?
          if promotion.present? && promotion.actions.exists?
            handle_present_promotion(promotion)
          else
            self.error = Spree.t(:coupon_code_not_found)
          end
        end

        self
      end

      def promotion
        @promotion ||= Promotion.active.includes(:promotion_rules).find_by(code: order.coupon_code)
      end

      private

      def handle_present_promotion(promotion)
        return promotion_usage_limit_exceeded if promotion.usage_limit_exceeded?

        # If any of the actions for the promotion return `true`,
        # then result here will also be `true`.
        result = promotion.activate(:order => order)
        if result
          determine_promotion_application_result(result)
        else
          self.error = Spree.t(:coupon_code_already_applied)
        end
      end

      def promotion_usage_limit_exceeded
        self.error = Spree.t(:coupon_code_max_usage)
      end

      def determine_promotion_application_result(result)
        previous_promo = order.adjustments.promotion.eligible.first
        discount = order.line_item_adjustments.promotion.detect { |p| p.source.promotion.code == order.coupon_code }

        if result and discount.eligible
          self.success = Spree.t(:coupon_code_applied)
        elsif previous_promo.present? and discount.present?
          self.error = Spree.t(:coupon_code_better_exists)
        elsif discount.present?
          self.error = Spree.t(:coupon_code_not_eligible)
        else
          # if the promotion was created after the order
          self.error = Spree.t(:coupon_code_not_found)
        end
      end
    end
  end
end
