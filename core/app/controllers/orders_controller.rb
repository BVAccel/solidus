class OrdersController < Spree::BaseController
  # prepend_before_filter :reject_unknown_object,  :only => [:show, :edit, :update, :checkout]
  # before_filter :prevent_editing_complete_order, :only => [:edit, :update, :checkout]
  # before_filter :set_user

  ssl_required :show

  resource_controller

  helper :products

  #create.before :create_before

  # override the default r_c behavior (remove flash - redirect to edit details instead of show)
  # create do
  #   flash nil
  #   success.wants.html {redirect_to edit_order_url(@order)}
  #   failure.wants.html { render :template => "orders/edit" }
  # end
  #
  # update.before do
  #   # Temporary workaround for problem in Rails 2.3.8 where updating with nested attributes doesn't work if the collection isn't loaded
  #   object.line_items(true)
  # end
  #
  # # override the default r_c flash behavior
  # update do
  #   flash nil
  #   success.wants.html { redirect_to edit_order_url(object) }
  #   failure.wants.html { render :template => "orders/edit" }
  # end

  #override r_c default b/c we don't want to actually destroy, we just want to clear line items
  # def destroy
  #   flash.notice = I18n.t(:basket_successfully_cleared)
  #   @order.line_items.clear\t
  #   @order.update_totals!
  #   after :destroy
  #   set_flash :destroy
  #   response_for :destroy
  # end
  #
  # destroy.response do |wants|
  #   wants.html { redirect_to(edit_object_url) }
  # end

  # Shows the current incomplete order from the session
  def cart
    @order = current_order
  end

  # Adds a new item to the order (creating a new order if none already exists)
  #
  # Parameters can be passed using the following possible parameter configurations:
  #
  # * Single variant/quantity pairing
  # +:variants => {variant_id => quantity}+
  #
  # * Multiple products at once (TODO double check this is correct)
  # +:products => {product_id => {variant_id => {:quantity => quantity}, variant_id => {:quantity => quantity}, ...} +
  # +:products => {product_id => {variant_id => {:quantity => [:variant_id => quantity, :variant_id => quantity, ...] }+
  def populate
    @order = current_order(true)
    params[:variants].each do |variant_id, quantity|
      @order.add_variant(Variant.find(variant_id), quantity.to_i) #if quantity > 0
    end if params[:variants]
    redirect_to cart_path
  end

  private

  def object
    @object ||= Order.find_by_number(params[:id], :include => :adjustments) if params[:id]
    @object
  end

  # def create_before
  #
  #   # store order token in the session
  #   session[:order_token] = @order.token
  # end

  # def prevent_editing_complete_order
  #   load_object
  #   redirect_to object_url if @order.checkout_complete
  # end

  # def set_user
  #   #only if the user is blank and the order is in_progress
  #   if @order && @order.user.nil? && @order.in_progress? && current_user
  #     @order.checkout.update_attribute(:email, current_user.email) if @order.checkout
  #     @order.user = current_user
  #     @order.save
  #   end
  # end
  #
  # def accurate_title
  #   I18n.t(:shopping_cart)
  # end
end
