from pathlib import Path
import hashlib

path = Path('/app/cbn-operations/operations.rb')
original = path.read_bytes()
if hashlib.sha256(original).hexdigest() != 'f0d686d5dd65e9fcab1fe09a1d91ac8487a09e7f5668ae9617d8597edf9aaacc':
    raise RuntimeError('Operations baseline changed; refusing patch')
source = original.decode()
start = source.index('  class ScheduledMessage < ApplicationRecord\n')
end = source.index('  class DialerEvent < ApplicationRecord\n')
source = source[:start] + Path('/patch/scheduled_message.rb').read_text() + '\n' + source[end:]
start = source.index('  class SchedulesController < ')
end = source.index('  class DialerController < ')
source = source[:start] + Path('/patch/schedules_controller.rb').read_text() + '\n' + source[end:]
anchor = "{ content: row.content, message_type: 'outgoing', private: false,"
if source.count(anchor) != 1:
    raise RuntimeError('Dispatch insertion point changed')
source = source.replace(anchor, "{ content: row.content, attachments: row.files.blobs.map(&:signed_id), message_type: 'outgoing', private: false,", 1)
source = "Rails.application.config.filter_parameters += [:attachments, :remove_attachment_ids]\n" + source
path.write_text(source)
