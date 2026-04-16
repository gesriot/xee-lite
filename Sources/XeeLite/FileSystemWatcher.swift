import Dispatch
import Foundation
import Darwin

final class FileSystemWatcher {
    private let source: DispatchSourceFileSystemObject

    init?(
        url: URL,
        eventMask: DispatchSource.FileSystemEvent,
        queue: DispatchQueue = DispatchQueue(label: "XeeLite.FileSystemWatcher", qos: .utility),
        onEvent: @escaping () -> Void
    ) {
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return nil }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: eventMask,
            queue: queue
        )

        source.setEventHandler(handler: onEvent)
        source.setCancelHandler {
            close(fileDescriptor)
        }
        source.resume()
    }

    deinit {
        source.cancel()
    }
}
