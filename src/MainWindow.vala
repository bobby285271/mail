// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.MainWindow : Hdy.ApplicationWindow {
    private HeaderBar headerbar;
    private Gtk.Paned paned_end;
    private Gtk.Paned paned_start;
    private Gtk.Grid container_grid;

    private FoldersListView folders_list_view;
    private Gtk.Overlay conversation_list_overlay;
    private ConversationListBox conversation_list_box;
    private Gtk.ScrolledWindow conversation_list_scrolled;
    private MessageListBox message_list_box;
    private Gtk.ScrolledWindow message_list_scrolled;

    private uint configure_id;

    public const string ACTION_GROUP_PREFIX = "win";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string ACTION_COMPOSE_MESSAGE = "compose_message";
    public const string ACTION_REPLY = "reply";
    public const string ACTION_REPLY_ALL = "reply-all";
    public const string ACTION_FORWARD = "forward";
    public const string ACTION_MARK_READ = "mark-read";
    public const string ACTION_MARK_STAR = "mark-star";
    public const string ACTION_MARK_UNREAD = "mark-unread";
    public const string ACTION_MARK_UNSTAR = "mark-unstar";
    public const string ACTION_ARCHIVE = "archive";
    public const string ACTION_MOVE_TO_TRASH = "trash";
    public const string ACTION_FULLSCREEN = "full-screen";

    private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_COMPOSE_MESSAGE, on_compose_message },
        {ACTION_REPLY, on_reply },
        {ACTION_REPLY_ALL, on_reply_all },
        {ACTION_FORWARD, on_forward },
        {ACTION_MARK_READ, on_mark_read },
        {ACTION_MARK_STAR, on_mark_star },
        {ACTION_MARK_UNREAD, on_mark_unread },
        {ACTION_MARK_UNSTAR, on_mark_unstar },
        {ACTION_ARCHIVE, on_archive },
        {ACTION_MOVE_TO_TRASH, on_move_to_trash },
        {ACTION_FULLSCREEN, on_fullscreen },
    };

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            height_request: 600,
            icon_name: "io.elementary.mail",
            width_request: 800,
            title: _("Mail")
        );
    }

    static construct {
        Hdy.init ();

        action_accelerators[ACTION_COMPOSE_MESSAGE] = "<Control>N";
        action_accelerators[ACTION_REPLY] = "<Control>R";
        action_accelerators[ACTION_REPLY_ALL] = "<Control><Shift>R";
        action_accelerators[ACTION_FORWARD] = "<Ctrl><Shift>F";
        action_accelerators[ACTION_MARK_READ] = "<Ctrl><Shift>i";
        action_accelerators[ACTION_MARK_STAR] = "<Ctrl>l";
        action_accelerators[ACTION_MARK_UNREAD] = "<Ctrl><Shift>u";
        action_accelerators[ACTION_MARK_UNSTAR] = "<Ctrl><Shift>l";
        action_accelerators[ACTION_ARCHIVE] = "<Ctrl><Shift>a";
        action_accelerators[ACTION_MOVE_TO_TRASH] = "Delete";
        action_accelerators[ACTION_MOVE_TO_TRASH] = "BackSpace";
        action_accelerators[ACTION_FULLSCREEN] = "F11";
    }

    construct {
        add_action_entries (ACTION_ENTRIES, this);
        get_action (ACTION_COMPOSE_MESSAGE).set_enabled (false);

        foreach (var action in action_accelerators.get_keys ()) {
            ((Gtk.Application) GLib.Application.get_default ()).set_accels_for_action (
                ACTION_PREFIX + action,
                action_accelerators[action].to_array ()
            );
        }

        headerbar = new HeaderBar ();

        folders_list_view = new FoldersListView ();
        conversation_list_box = new ConversationListBox ();

        // Disable delete accelerators when the conversation list box loses keyboard focus,
        // restore them when it returns
        conversation_list_box.set_focus_child.connect ((widget) => {
            if (widget == null) {
                ((Gtk.Application) GLib.Application.get_default ()).set_accels_for_action (
                    ACTION_PREFIX + ACTION_MOVE_TO_TRASH,
                    {}
                );
            } else {
                ((Gtk.Application) GLib.Application.get_default ()).set_accels_for_action (
                    ACTION_PREFIX + ACTION_MOVE_TO_TRASH,
                    action_accelerators[ACTION_MOVE_TO_TRASH].to_array ()
                );
            }
        });

        message_list_box = new MessageListBox ();
        message_list_box.bind_property ("can-reply", get_action (ACTION_REPLY), "enabled", BindingFlags.SYNC_CREATE);
        message_list_box.bind_property ("can-reply", get_action (ACTION_REPLY_ALL), "enabled", BindingFlags.SYNC_CREATE);
        message_list_box.bind_property ("can-reply", get_action (ACTION_FORWARD), "enabled", BindingFlags.SYNC_CREATE);
        message_list_box.bind_property ("can-move-thread", get_action (ACTION_MOVE_TO_TRASH), "enabled", BindingFlags.SYNC_CREATE);
        message_list_box.bind_property ("can-move-thread", get_action (ACTION_ARCHIVE), "enabled", BindingFlags.SYNC_CREATE);
        message_list_box.bind_property ("can-move-thread", headerbar, "can-mark", BindingFlags.SYNC_CREATE);

        conversation_list_scrolled = new Gtk.ScrolledWindow (null, null);
        conversation_list_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        conversation_list_scrolled.width_request = 158;
        conversation_list_scrolled.add (conversation_list_box);

        conversation_list_overlay = new Gtk.Overlay ();
        conversation_list_overlay.add (conversation_list_scrolled);

        message_list_scrolled = new Gtk.ScrolledWindow (null, null);
        message_list_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        message_list_scrolled.add (message_list_box);
        // Prevent the focus of the webview causing the ScrolledWindow to scroll
        var scrolled_child = message_list_scrolled.get_child ();
        if (scrolled_child is Gtk.Container) {
            ((Gtk.Container) scrolled_child).set_focus_vadjustment (new Gtk.Adjustment (0, 0, 0, 0, 0, 0));
        }

        var view_overlay = new Gtk.Overlay ();
        view_overlay.add (message_list_scrolled);
        var message_overlay = new Granite.Widgets.OverlayBar (view_overlay);
        message_overlay.no_show_all = true;
        message_list_box.hovering_over_link.connect ((label, url) => {
            var hover_url = url != null ? Soup.URI.decode (url) : null;

            if (hover_url == null) {
                message_overlay.hide ();
            } else {
                message_overlay.label = hover_url;
                message_overlay.show ();
            }
        });

        paned_start = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_start.pack1 (folders_list_view, false, false);
        paned_start.pack2 (conversation_list_overlay, true, false);

        paned_end = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_end.pack1 (paned_start, false, false);
        paned_end.pack2 (view_overlay, true, true);

        var welcome_view = new Mail.WelcomeView ();

        var placeholder_stack = new Gtk.Stack ();
        placeholder_stack.transition_type = Gtk.StackTransitionType.OVER_DOWN_UP;
        placeholder_stack.add_named (paned_end, "mail");
        placeholder_stack.add_named (welcome_view, "welcome");

        container_grid = new Gtk.Grid ();
        container_grid.attach (headerbar, 0, 0);
        container_grid.attach (placeholder_stack, 0, 1);

        add (container_grid);

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("paned-start-position", paned_start, "position", SettingsBindFlags.DEFAULT);
        settings.bind ("paned-end-position", paned_end, "position", SettingsBindFlags.DEFAULT);

        destroy.connect (() => destroy ());

        folders_list_view.folder_selected.connect ((folder_full_name_per_account) => {
            conversation_list_box.load_folder.begin (folder_full_name_per_account);
        });

        conversation_list_box.conversation_selected.connect ((node) => {
            message_list_box.set_conversation (node);

            if (node != null && node.message != null && Camel.MessageFlags.DRAFT in (int) node.message.flags) {
                message_list_box.add_inline_composer.begin (ComposerWidget.Type.DRAFT, null, (obj, res) => {
                    message_list_box.add_inline_composer.end (res);
                    scroll_message_list_to_bottom ();
                });
            }
        });

        headerbar.size_allocate.connect (() => {
            headerbar.set_paned_positions (paned_start.position, paned_end.position);
        });

        paned_end.notify["position"].connect (() => {
            headerbar.set_paned_positions (paned_start.position, paned_end.position, false);
        });

        paned_start.notify["position"].connect (() => {
            headerbar.set_paned_positions (paned_start.position, paned_end.position);
        });

        headerbar.search_entry.search_changed.connect (() => {
            conversation_list_box.search (headerbar.search_entry.text);
        });

        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
        session.account_added.connect (() => {
            placeholder_stack.visible_child = paned_end;
            get_action (ACTION_COMPOSE_MESSAGE).set_enabled (true);
            headerbar.can_search = true;
        });

        session.account_removed.connect (() => {
            var accounts_left = session.get_accounts ();
            if (accounts_left.size == 0) {
                get_action (ACTION_COMPOSE_MESSAGE).set_enabled (false);
                headerbar.can_search = false;
            }
        });

        session.start.begin ();
    }

    private void on_compose_message () {
        new ComposerWindow (this).show_all ();
    }

    private void scroll_message_list_to_bottom () {
        // Adding the inline composer then trying to scroll to the bottom doesn't work as
        // the scrolled window doesn't resize instantly. So connect a one time signal to
        // scroll to the bottom when the inline composer is added
        var adjustment = message_list_scrolled.get_vadjustment ();
        ulong changed_id = 0;
        changed_id = adjustment.changed.connect (() => {
            adjustment.set_value (adjustment.get_upper ());
            adjustment.disconnect (changed_id);
        });
    }

    private void on_mark_read () {
        conversation_list_box.mark_read_selected_messages ();
    }

    private void on_mark_star () {
        conversation_list_box.mark_star_selected_messages ();
    }

    private void on_mark_unread () {
        conversation_list_box.mark_unread_selected_messages ();
    }

    private void on_mark_unstar () {
        conversation_list_box.mark_unstar_selected_messages ();
    }

    private void on_reply () {
        scroll_message_list_to_bottom ();
        message_list_box.add_inline_composer.begin (ComposerWidget.Type.REPLY);
    }

    private void on_reply_all () {
        scroll_message_list_to_bottom ();
        message_list_box.add_inline_composer.begin (ComposerWidget.Type.REPLY_ALL);
    }

    private void on_forward () {
        scroll_message_list_to_bottom ();
        message_list_box.add_inline_composer.begin (ComposerWidget.Type.FORWARD);
    }

    private void on_archive () {
        conversation_list_box.archive_selected_messages.begin ((obj, res) => {
            conversation_list_box.archive_selected_messages.end (res);
        });
    }

    private void on_move_to_trash () {
        var result = conversation_list_box.trash_selected_messages ();
        if (result > 0) {
            send_move_toast (ngettext ("Message Deleted", "Messages Deleted", result));
        }
    }

    private void send_move_toast (string message) {
        foreach (weak Gtk.Widget child in conversation_list_overlay.get_children ()) {
            if (child != conversation_list_scrolled) {
                child.destroy ();
            }
        }

        var toast = new Granite.Widgets.Toast (message);
        toast.set_default_action (_("Undo"));
        toast.show_all ();

        toast.default_action.connect (() => {
            conversation_list_box.undo_move ();
        });

        toast.notify["child-revealed"].connect (() => {
            if (!toast.child_revealed) {
                conversation_list_box.undo_expired ();
            }
        });

        conversation_list_overlay.add_overlay (toast);
        toast.send_notification ();
    }

    private void on_fullscreen () {
        if (Gdk.WindowState.FULLSCREEN in get_window ().get_state ()) {
            headerbar.show_close_button = true;
            unfullscreen ();
        } else {
            headerbar.show_close_button = false;
            fullscreen ();
        }
    }

    private SimpleAction? get_action (string name) {
        return lookup_action (name) as SimpleAction;
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id != 0) {
            GLib.Source.remove (configure_id);
        }

        configure_id = Timeout.add (100, () => {
            configure_id = 0;

            if (is_maximized) {
                Mail.Application.settings.set_boolean ("window-maximized", true);
            } else {
                Mail.Application.settings.set_boolean ("window-maximized", false);

                Gdk.Rectangle rect;
                get_allocation (out rect);
                Mail.Application.settings.set ("window-size", "(ii)", rect.width, rect.height);

                int root_x, root_y;
                get_position (out root_x, out root_y);
                Mail.Application.settings.set ("window-position", "(ii)", root_x, root_y);
            }

            return false;
        });

        return base.configure_event (event);
    }
}
