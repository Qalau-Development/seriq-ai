"""История занятий: занятия и попытки

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-25 00:41:38.555919
"""
from alembic import op
import sqlalchemy as sa


revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


# upgrade — применяет миграцию
def upgrade() -> None:
    op.create_table('sessions',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('exercise', sa.String(length=3), nullable=False),
    sa.Column('started_at', sa.DateTime(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_sessions_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_sessions'))
    )
    with op.batch_alter_table('sessions', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_sessions_user_id'), ['user_id'], unique=False)

    op.create_table('attempts',
    sa.Column('analysis_id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('session_id', sa.String(length=36), nullable=False),
    sa.Column('at', sa.DateTime(), nullable=False),
    sa.Column('source', sa.String(length=5), nullable=False),
    sa.Column('model_version', sa.String(length=64), nullable=False),
    sa.Column('verdict', sa.String(length=20), nullable=False),
    sa.Column('label', sa.String(length=10), nullable=False),
    sa.Column('confidence', sa.Float(), nullable=False),
    sa.Column('measure_value', sa.Float(), nullable=True),
    sa.Column('measure', sa.JSON(), nullable=True),
    sa.ForeignKeyConstraint(['session_id'], ['sessions.id'], name=op.f('fk_attempts_session_id_sessions'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_attempts_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('analysis_id', name=op.f('pk_attempts'))
    )
    with op.batch_alter_table('attempts', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_attempts_session_id'), ['session_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_attempts_user_id'), ['user_id'], unique=False)



# downgrade — откатывает миграцию
def downgrade() -> None:
    with op.batch_alter_table('attempts', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_attempts_user_id'))
        batch_op.drop_index(batch_op.f('ix_attempts_session_id'))

    op.drop_table('attempts')
    with op.batch_alter_table('sessions', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_sessions_user_id'))

    op.drop_table('sessions')
