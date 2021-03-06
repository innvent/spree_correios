module Spree
  class Calculator::CorreiosBaseCalculator < Calculator
    preference :zipcode, :string
    preference :token, :string
    preference :password, :string
    preference :declared_value, :boolean, default: false
    preference :receipt_notification, :boolean, default: false
    preference :receive_in_hands, :boolean, default: false

    attr_reader :delivery_time
    attr_accessible :preferred_zipcode, :preferred_token,
                    :preferred_password, :preferred_declared_value,
                    :preferred_receipt_notification, :preferred_receive_in_hands

    def compute(object)
      return unless object.present? and object.line_items.present?

      order      = object.is_a?(Spree::Order) ? object : object.order
      package    = package_from_order(order)
      calculator = calculator_for_package_of_order(package, order)
      webservice = calculator.calculate(shipping_method)

      return 0.0 if webservice.erro?

      @delivery_time = webservice.prazo_entrega
      webservice.valor
    rescue 0.0 # TODO: log webservice errors or let exceptions goes up
    end

    def available?(order)
      !compute(order).zero?
    end

    def has_contract?
      preferred_token.present? && preferred_password.present?
    end

    def package_from_order(order)
      ::Correios::Frete::Pacote.new.tap do |package|
        order.line_items.map do |item|
          weight = item.product.weight.to_f
          depth  = item.product.depth.to_f
          width  = item.product.width.to_f
          height = item.product.height.to_f
          package_item = ::Correios::Frete::PacoteItem.new(peso: weight, comprimento: depth, largura: width, altura: height)
          package.add_item(package_item)
        end
      end
    end

    def calculator_for_package_of_order(package, order)
      ::Correios::Frete::Calculador.new do |c|
        c.encomenda         = package

        c.cep_origem        = preferred_zipcode
        c.cep_destino       = order.ship_address.zipcode
        c.valor_declarado   = order.amount.to_f  if prefers?(:declared_value)

        c.codigo_empresa    = preferred_token    if preferred_token.present?
        c.senha             = preferred_password if preferred_password.present?

        c.mao_propria       = prefers?(:receive_in_hands)
        c.aviso_recebimento = prefers?(:receipt_notification)
      end
    end
  end
end
