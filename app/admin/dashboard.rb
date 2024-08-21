# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }
  content title: proc { I18n.t('active_admin.dashboard') } do

    section "Contenido actualizado recientemente" do
      table_for PaperTrail::Version.order(id: :desc).limit(20) do # Use PaperTrail::Version if this throws an error
        # column ("Item") { |v| v.item_id }
        column ("Item") { |v| link_to v.item.name, [:admin, v.item] } # Uncomment to display as link
        column ("Tipo") { |v| v.item_type.underscore.humanize }
        # column ("Modified at") { |v| v.created_at.to_s :long }
        # column ("Fecha de Modificacion") { |v| v.created_at.strftime('%d de %B, %Y %H:%M:%S') }
        column ("Fecha de Modificacion") { |v| v.created_at.strftime('%d/%m/%Y - %H:%M:%S') }
        column ("Admin") { |v| link_to AdminUser.find(v.whodunnit).email, [:admin, AdminUser.find(v.whodunnit)] }
      end
    end

  end
end
