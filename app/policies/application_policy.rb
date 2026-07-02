# Base de autorização (Action Policy, Q40/Q41). A decisão canônica "pode/não pode"
# mora AQUI, não em before_action ad-hoc — controllers chamam authorize!.
#
# `user` é o contexto de autorização, resolvido de Current.user (ver
# ApplicationController#authorization_context).
#
# ISOLAMENTO POR TENANT (Q23, Fatia 2.1): o `relation_scope` abaixo é o piso do
# multi-tenant — filtra qualquer relação pro user do contexto (a bolha isolada). As
# policies de domínio (Clients/Projects/Tasks/TimeEntries/Tags), ao nascer, herdam
# daqui e ganham o escopo de graça; refinam SÓ se precisarem de mais. O ownership
# base (`manage?`) nega record de outra conta comparando `user_id`. Admin NÃO ganha
# acesso ao domínio por aqui (Q23/Q25b): o painel de admin herda de Admin::BasePolicy,
# uma árvore SEPARADA — admin é cego pro domínio alheio.
class ApplicationPolicy < ActionPolicy::Base
  authorize :user

  # Todo record de domínio pertence a um user (`user_id`). O escopo padrão de
  # relação (Active Record) devolve só os records do user do contexto — é o que
  # `authorized_scope Model.all` aplica nos controllers/views.
  relation_scope do |relation|
    relation.where(user: user)
  end

  # Piso de ownership pra ações SOBRE UM RECORD (show/edit/update/destroy): só o dono
  # manipula o próprio record — compara `user_id`. As ações de COLEÇÃO (index/new/
  # create) não têm um record concreto (o "record" é a classe), então NÃO podem cair
  # em manage? (que dereferencia record.user_id). Elas caem em collection? — que só
  # exige um user autenticado; o isolamento real vem do relation_scope (index) e do
  # escopo no set_record (member). Admin sobrescreve tudo isso na Admin::BasePolicy.
  default_rule :manage?
  alias_rule :show?, :edit?, :update?, :destroy?, to: :manage?
  alias_rule :index?, :new?, :create?, to: :collection?

  def manage?
    record.user_id == user&.id
  end

  def collection?
    user.present?
  end

  private
    def admin?
      user&.admin?
    end
end
