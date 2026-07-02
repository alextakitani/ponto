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

  # Piso de ownership: só o dono manipula o próprio record. Policies de domínio
  # herdam isto; as regras CRUD (index?/show?/create?/update?/destroy?) do Action
  # Policy caem no default_rule, então aliasamos pra manage? aqui embaixo.
  default_rule :manage?
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, to: :manage?

  def manage?
    record.user_id == user&.id
  end

  private
    def admin?
      user&.admin?
    end
end
