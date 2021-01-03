// Copyright © 2020 Metabolist. All rights reserved.

import Combine
import Kingfisher
import UIKit
import ViewModels

final class CompositionView: UIView {
    let avatarImageView = UIImageView()
    let spoilerTextField = UITextField()
    let textView = UITextView()
    let textViewPlaceholder = UILabel()
    let attachmentsCollectionView: UICollectionView
    let attachmentUploadView: AttachmentUploadView

    private let viewModel: CompositionViewModel
    private let parentViewModel: NewStatusViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var attachmentsDataSource: CompositionAttachmentsDataSource = {
        let vm = viewModel

        return .init(collectionView: attachmentsCollectionView) {
            (vm.attachmentViewModels[$0.item], vm)
        }
    }()

    init(viewModel: CompositionViewModel, parentViewModel: NewStatusViewModel) {
        self.viewModel = viewModel
        self.parentViewModel = parentViewModel

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .estimated(Self.attachmentCollectionViewHeight),
            heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(Self.attachmentCollectionViewHeight),
            heightDimension: .fractionalHeight(1))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item])
        let section = NSCollectionLayoutSection(group: group)

        section.interGroupSpacing = .defaultSpacing

        let configuration = UICollectionViewCompositionalLayoutConfiguration()

        configuration.scrollDirection = .horizontal

        let attachmentsLayout = UICollectionViewCompositionalLayout(section: section, configuration: configuration)

        attachmentsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: attachmentsLayout)
        attachmentUploadView = AttachmentUploadView(viewModel: viewModel)

        super.init(frame: .zero)

        initialSetup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CompositionView {
    var id: CompositionViewModel.Id { viewModel.id }
}

extension CompositionView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.text = textView.text
    }
}

private extension CompositionView {
    static let attachmentCollectionViewHeight: CGFloat = 200

    // swiftlint:disable:next function_body_length
    func initialSetup() {
        tag = viewModel.id.hashValue

        addSubview(avatarImageView)
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.layer.cornerRadius = .avatarDimension / 2
        avatarImageView.clipsToBounds = true

        let stackView = UIStackView()
        let inputAccessoryView = CompositionInputAccessoryView(viewModel: viewModel, parentViewModel: parentViewModel)

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = .defaultSpacing

        stackView.addArrangedSubview(spoilerTextField)
        spoilerTextField.borderStyle = .roundedRect
        spoilerTextField.adjustsFontForContentSizeCategory = true
        spoilerTextField.font = .preferredFont(forTextStyle: .body)
        spoilerTextField.placeholder = NSLocalizedString("status.spoiler-text-placeholder", comment: "")
        spoilerTextField.inputAccessoryView = inputAccessoryView
        spoilerTextField.addAction(
            UIAction { [weak self] _ in
                guard let self = self, let text = self.spoilerTextField.text else { return }

                self.viewModel.contentWarning = text
            },
            for: .editingChanged)

        let textViewFont = UIFont.preferredFont(forTextStyle: .body)

        stackView.addArrangedSubview(textView)
        textView.isScrollEnabled = false
        textView.adjustsFontForContentSizeCategory = true
        textView.font = textViewFont
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.inputAccessoryView = inputAccessoryView
        textView.inputAccessoryView?.sizeToFit()
        textView.delegate = self

        textView.addSubview(textViewPlaceholder)
        textViewPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        textViewPlaceholder.adjustsFontForContentSizeCategory = true
        textViewPlaceholder.font = .preferredFont(forTextStyle: .body)
        textViewPlaceholder.textColor = .secondaryLabel
        textViewPlaceholder.text = NSLocalizedString("compose.prompt", comment: "")

        stackView.addArrangedSubview(attachmentsCollectionView)
        attachmentsCollectionView.dataSource = attachmentsDataSource
        attachmentsCollectionView.backgroundColor = .clear

        stackView.addArrangedSubview(attachmentUploadView)

        textView.text = viewModel.text
        spoilerTextField.text = viewModel.contentWarning

        let textViewBaselineConstraint = textView.topAnchor.constraint(
            lessThanOrEqualTo: avatarImageView.centerYAnchor,
            constant: -textViewFont.lineHeight / 2)

        viewModel.$text.map(\.isEmpty)
            .sink { [weak self] in self?.textViewPlaceholder.isHidden = !$0 }
            .store(in: &cancellables)

        viewModel.$displayContentWarning
            .sink { [weak self] in
                guard let self = self else { return }

                if self.spoilerTextField.isHidden && self.textView.isFirstResponder && $0 {
                    self.spoilerTextField.becomeFirstResponder()
                } else if !self.spoilerTextField.isHidden && self.spoilerTextField.isFirstResponder && !$0 {
                    self.textView.becomeFirstResponder()
                }

                self.spoilerTextField.isHidden = !$0
                textViewBaselineConstraint.isActive = !$0
            }
            .store(in: &cancellables)

        parentViewModel.$identification.map(\.identity.image)
            .sink { [weak self] in self?.avatarImageView.kf.setImage(with: $0) }
            .store(in: &cancellables)

        viewModel.$attachmentViewModels
            .sink { [weak self] in
                self?.attachmentsDataSource.apply($0.map(\.attachment).snapshot())
                self?.attachmentsCollectionView.isHidden = $0.isEmpty
            }
            .store(in: &cancellables)

        let guide = UIDevice.current.userInterfaceIdiom == .pad ? readableContentGuide : layoutMarginsGuide
        let constraints = [
            avatarImageView.heightAnchor.constraint(equalToConstant: .avatarDimension),
            avatarImageView.widthAnchor.constraint(equalToConstant: .avatarDimension),
            avatarImageView.topAnchor.constraint(equalTo: guide.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            avatarImageView.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: .defaultSpacing),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor),
            stackView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor),
            textViewPlaceholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            textViewPlaceholder.topAnchor.constraint(equalTo: textView.topAnchor),
            textViewPlaceholder.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            attachmentsCollectionView.heightAnchor.constraint(equalToConstant: Self.attachmentCollectionViewHeight)
        ]

        if UIDevice.current.userInterfaceIdiom == .pad {
            for constraint in constraints {
                constraint.priority = .justBelowMax
            }
        }

        NSLayoutConstraint.activate(constraints)
    }
}
