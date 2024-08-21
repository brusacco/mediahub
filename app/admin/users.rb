ActiveAdmin.register User do

  # filters
  scope 'Todos', :all, default: :true

  filter :name, label: 'Nombre'
  filter :email
  filter :status

  # CRUD
  permit_params :name, :email, :status, :password, :password_confirmation, topic_ids: []
  form html: { enctype: 'multipart/form-data', multipart: true } do |f|
    if !f.object.new_record?
      panel 'Usuario' do
        "<h2>#{f.object.name.to_s}</h2>".html_safe
      end
    end
    columns do
      column do
        f.inputs "Actualizar datos de Usuario", :multipart => true do
          f.input :name, label: 'Nombre'
          f.input :email, label: 'Email'
          f.input :password, label: 'Contreseña'
          f.input :password_confirmation, label: 'Confirmar contreseña'
        end
      end
      column do
        f.inputs "Lista de Topicos", multipart: :true do
          f.input :topics, label:'Asiganar a:', as: :check_boxes, :collection => Topic.all.collect {|topic| [topic.name, topic.id]}
        end
      end
    end
    f.actions
  end

  # INDEX
  index title: 'Usuarios' do
    selectable_column
    # index_column
    id_column
    column 'Nombre', sortable: :name do |c|
      link_to c.name, admin_user_path(c)
    end
    column :email

    column "Tópico(s) asignado(s)" do |user|
      user.topics.map { |topic| link_to topic.name, admin_topic_path(topic) }.join('<br />').html_safe
    end

    column 'Fecha de Creación', :created_at
    column 'Fecha de Actualización', :updated_at
    actions
  end
end
